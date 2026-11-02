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
import 'package:loop_mobile/features/shell/loop_shell.dart' show loopTabBarEdge;
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
import 'package:loop_mobile/widgets/loop_pressable.dart';
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
      // S335 (decision 0264): no 热门社区 banner and no 「全部社区」 heading;
      // the order is one quiet word, right-aligned over the cards.
      _SquareSortButton(
        label: selectedSegment.label,
        onTap: () => unawaited(_chooseSort(selectedSegment)),
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
        // S335 (decision 0264): one card per community, each its own list
        // child so a long directory builds only the cards on screen.
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

/// 「成员最多 ∨」: the current order as one quiet Text3 word, right-aligned
/// over the cards, opening the four orders the directory takes (UX-013,
/// decision 0257; S335 · decision 0264 dropped its chip and its heading).
class _SquareSortButton extends StatelessWidget {
  const _SquareSortButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: squareCommunityCardInset - 8),
    child: Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: '排序，$label',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey<String>('square-community-sort'),
          onTap: onTap,
          borderRadius: LoopRadius.pill,
          // The word reads as a 32 line; the hit box keeps the 44 floor.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: LoopTouch.minimum,
              minWidth: LoopTouch.minimum,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: LoopType.meta),
                  const SizedBox(width: 4),
                  const RotatedBox(
                    quarterTurns: 1,
                    child: LoopIcon(
                      'chevron',
                      size: 12,
                      color: LoopColors.text3,
                    ),
                  ),
                ],
              ),
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

/// The facts under a row's description, joined for the row's spoken label
/// only (the card draws them as separate pieces): members, the ranked fact
/// under an order that ranks by one, then the bound token.
String squareCommunitySubline(
  CommunitySummary community,
  CommunityDirectorySort sort,
) {
  final ranked = squareCommunityRankedFact(community, sort);
  final symbol = community.assetSymbol;
  return <String>[
    '${community.memberCount} 成员',
    ?ranked,
    if (symbol != null) '\$$symbol',
  ].join('，');
}

/// The fact an order ranks by (算力 / 7 天讨论 …), or null under an order
/// that ranks by members or age.
String? squareCommunityRankedFact(
  CommunitySummary community,
  CommunityDirectorySort sort,
) {
  final ranked = communityDirectoryRowFigure(community, sort: sort);
  return ranked == null ? null : '${ranked.caption} ${ranked.value}';
}

/// The card's measures (S335 · decision 0264, the requester's 390-wide
/// board): a card per community, 16 in from the screen edge, 12 apart, 16
/// inside, a 60 logo at a 14 corner; the facts line's chips 20 high.
const double squareCommunityCardInset = 16;
const double squareCommunityCardGap = 12;
const double squareCommunityCardPadding = 16;
const double squareCommunityLogoSize = 60;
const double squareCommunityLogoRadius = 14;
const double squareCommunityPillWidth = 52;
const double squareCommunityPillHeight = 32;
const double squareCommunityChipHeight = 20;
const double squareCommunityTokenLogoSize = 16;
const double squareCommunityMetaGap = 8;
const double squareCommunityTokenChipMaxWidth = 120;

/// One community as its own card (S335 · decision 0264): logo, name,
/// one line of description, the facts line — members, a hairline, the token,
/// and the operator's label at its end (decision 0239) — and the reader's
/// membership at the right. The whole card opens the community.
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

  @override
  Widget build(BuildContext context) {
    final id = community.communityId;
    final action = squareMembershipAction(community.viewerMembership);
    final subline = squareCommunitySubline(community, sort);
    final ranked = squareCommunityRankedFact(community, sort);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        squareCommunityCardInset,
        0,
        squareCommunityCardInset,
        squareCommunityCardGap,
      ),
      child: Material(
        key: ValueKey<String>('square-community-card-$id'),
        color: LoopColors.card,
        borderRadius: LoopRadius.shell,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label:
                    '${<String>[community.name, if (described) description, subline, if (label != null) communityLabelDisplay(label)].join('，')}'
                    '$state',
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey<String>('square-community-open-$id'),
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      squareCommunityCardPadding,
                      squareCommunityCardPadding,
                      8,
                      squareCommunityCardPadding,
                    ),
                    child: Row(
                      children: <Widget>[
                        CommunityLogo(
                          key: ValueKey<String>('square-community-logo-$id'),
                          identity: id,
                          name: community.name,
                          logoRef: community.logoRef,
                          size: squareCommunityLogoSize,
                          radius: squareCommunityLogoRadius,
                          chromeFallback: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                community.name,
                                key: ValueKey<String>(
                                  'square-community-name-$id',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopType.body1.copyWith(
                                  color: LoopColors.chalk,
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
                              const SizedBox(height: 6),
                              _SquareCommunityMeta(
                                communityId: id,
                                members: '${community.memberCount} 成员',
                                ranked: ranked,
                                symbol: community.assetSymbol,
                                logoUrl:
                                    community.assetBadge?.logoUrl ??
                                    community.boundAsset?.logoUrl,
                                label: label,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (action != SquareMembershipAction.none)
              Padding(
                padding: const EdgeInsets.only(
                  right: squareCommunityCardPadding,
                ),
                child: _MembershipCapsule(
                  communityId: id,
                  action: action,
                  joining: joining,
                  onJoin: onJoin,
                  onOpen: onOpen,
                ),
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// 「(people) 28 成员  [(logo) $DOGE]  [算力社区]」: the card's facts line
/// (S335 · decision 0264). Separate pieces 8 apart — no comma, no divider.
/// No bound token, no token chip; no label, no label chip.
class _SquareCommunityMeta extends StatelessWidget {
  const _SquareCommunityMeta({
    required this.communityId,
    required this.members,
    required this.ranked,
    required this.symbol,
    required this.logoUrl,
    required this.label,
  });

  final String communityId;
  final String members;
  final String? ranked;
  final String? symbol;
  final String? logoUrl;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final id = communityId;
    return SizedBox(
      key: ValueKey<String>('square-community-meta-$id'),
      height: squareCommunityChipHeight,
      child: Row(
        children: <Widget>[
          const LoopIcon('users', size: 14, color: LoopColors.text3),
          const SizedBox(width: 4),
          Text(
            members,
            key: ValueKey<String>('square-community-members-$id'),
            maxLines: 1,
            softWrap: false,
            style: LoopType.meta,
          ),
          if (ranked case final String fact) ...<Widget>[
            const SizedBox(width: squareCommunityMetaGap),
            Flexible(
              child: Text(
                fact,
                key: ValueKey<String>('square-community-ranked-$id'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: LoopType.meta,
              ),
            ),
          ],
          if (symbol case final String asset) ...<Widget>[
            const SizedBox(width: squareCommunityMetaGap),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: squareCommunityTokenChipMaxWidth,
              ),
              child: _SquareMetaChip(
                key: ValueKey<String>('square-community-token-$id'),
                leading: LoopTokenLogo(
                  key: ValueKey<String>('square-community-token-logo-$id'),
                  assetSymbol: asset,
                  logoUrl: logoUrl,
                  // 16 holds one letter, not two.
                  fallbackMonogram: loopMonogram(asset).characters.first,
                  size: squareCommunityTokenLogoSize,
                ),
                text: '\$$asset',
                color: LoopColors.chalk,
              ),
            ),
          ],
          // The label comes last and gives way first: whole when it fits,
          // cut after its first four characters at the least, otherwise left
          // off this line (the card's spoken label still carries it).
          if (label case final String mark)
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final text = communityLabelDisplay(mark);
                  final need =
                      squareCommunityMetaGap +
                      squareMetaChipFloor(context, text);
                  if (constraints.maxWidth < need) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: squareCommunityMetaGap,
                    ),
                    child: _SquareMetaChip(
                      key: ValueKey<String>('square-community-label-$id'),
                      text: text,
                      color: LoopColors.text3,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The narrowest a label chip may be drawn: its first four characters (and
/// an ellipsis when there is more) plus the chip's own padding and edge.
double squareMetaChipFloor(BuildContext context, String text) {
  final chars = text.characters;
  final shown = chars.length <= 4 ? text : '${chars.take(4)}…';
  final painter = TextPainter(
    text: TextSpan(text: shown, style: LoopType.tag),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width + squareMetaChipPadding * 2 + 2;
}

const double squareMetaChipPadding = 6;

/// A 20-high outlined chip on the facts line: the tab bar's own hairline
/// edge, a 10 corner, an optional 16 logo, one 12 / 600 word.
class _SquareMetaChip extends StatelessWidget {
  const _SquareMetaChip({
    required this.text,
    required this.color,
    super.key,
    this.leading,
  });

  final String text;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    height: squareCommunityChipHeight,
    padding: EdgeInsets.only(
      left: leading == null ? squareMetaChipPadding : 2,
      right: squareMetaChipPadding,
    ),
    decoration: BoxDecoration(
      borderRadius: LoopRadius.inner,
      border: Border.all(color: loopTabBarEdge),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading case final Widget logo) ...<Widget>[
          logo,
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: LoopType.tag.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
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
      bool primary,
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
    final word = joining ? '加入中' : label;
    // Decision 0212 (docs/42 附C §6): 「加入」 is the Yellow primary step —
    // the one thing on the card that asks to be tapped; 「已加入」 and the
    // others are the quiet grey capsule (S335 · decision 0264: 52 × 32).
    final solid = primary && onTap != null;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: word,
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>('square-community-$key-$communityId'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopTouch.minimum,
            minWidth: LoopTouch.minimum,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              key: ValueKey<String>('square-community-pill-$communityId'),
              height: squareCommunityPillHeight,
              constraints: const BoxConstraints(
                minWidth: squareCommunityPillWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: solid ? LoopColors.yellow : LoopColors.card2,
                borderRadius: LoopRadius.pill,
              ),
              child: Text(
                word,
                maxLines: 1,
                softWrap: false,
                style: LoopType.label.copyWith(
                  color: solid ? LoopColors.ink : LoopColors.text2,
                ),
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
