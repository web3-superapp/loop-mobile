import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart'
    show loopGroupedFigure;
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_search_entry.dart';
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
String get squareCommunityRuleLine =>
    LoopL10n.current.square_communityListSquareCommunityRuleLine;

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
      LoopToast.show(
        context,
        message: LoopL10n.current.square_communityListMessage,
      );
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
        barrierLabel: LoopL10n.current.square_communityListBarrierLabel,
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
      barrierLabel: LoopL10n.current.square_communityListBarrierLabel2,
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
      CommunityPreviewNotice(
        mode: mode,
        resource: context.l10n.square_communityListResource,
      ),
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
              message: context.l10n.square_communityListMessage2(
                selectedSegment.label,
              ),
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
                label: context
                    .l10n
                    .square_communityListSquareCommunityOrderingBackLabel,
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
          title:
              context.l10n.square_communityListSquareCommunityJoinedEmptyTitle,
          action: LoopButton(
            key: const ValueKey<String>('square-community-joined-empty-all'),
            label: context
                .l10n
                .square_communityListSquareCommunityJoinedEmptyAllLabel,
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
          // Decision 0248: one fact, no reason line.
          emptyMessage:
              context.l10n.square_communityListSquareCommunityStateEmptyMessage,
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
              label: context.l10n.common_retry,
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
      title: context.l10n.common_community,
      kicker: communityPreviewKicker(mode),
      embedded: true,
      tabPage: true,
      scrollsUnderTabBar: true,
      block: blocked
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'square-community-capability-unavailable',
              ),
              capability: capability,
              title: context
                  .l10n
                  .square_communityListSquareCommunityCapabilityUnavailableTitle,
            )
          : null,
      onRefresh: controller.refresh,
      updating: state.refreshing,
      collection: CustomScrollView(
        key: const ValueKey<String>('square-community-scroll'),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _SquareHeaderLine(
              onRules: () => unawaited(_showRules(state.recommendation)),
            ),
          ),
          // S350a · decision 0274: the search field and 全部 / 我加入的 share
          // one pinned line, so the cards start one control row higher.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedChips(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  squareCommunityCardInset,
                  _PinnedChips.inset,
                  squareCommunityCardInset,
                  _PinnedChips.inset,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _SquareSearchEntry(onTap: _openSearch)),
                    const SizedBox(width: 8),
                    _SquareMainTabs(
                      membership: state.membership,
                      onMembership: (filter) =>
                          unawaited(controller.selectMembership(filter)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 24 + loopTabScrollBottom(context)),
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
                context.l10n.square_communityListBuild,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // docs/58 §5.9: the small block heading, 16 / 700.
                style: LoopType.headlineSm,
              ),
            ),
          ),
          _SquareTextLink(
            key: const ValueKey<String>('square-community-rules'),
            label: context.l10n.square_communityListSquareCommunityRulesLabel,
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
                style: LoopType.meta.copyWith(color: LoopColors.textSecondary),
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
        label: context.l10n.square_communityListSquareCommunitySortLabel(label),
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
                  // docs/58 §5.3: 「成员最多」 at 12 / 500 in textSecondary.
                  Text(
                    label,
                    style: LoopType.meta.copyWith(
                      color: LoopColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const RotatedBox(
                    quarterTurns: 1,
                    child: LoopIcon(
                      'chevron',
                      size: 12,
                      color: LoopColors.textSecondary,
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
      LoopSheetHeading(context.l10n.square_communityListLoopSheetHeading),
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
  Widget build(BuildContext context) => LoopSearchEntry(
    // Decision 0277: the Figma's 44 search field. S353a · decision 0278:
    // the one word, so it fits whole beside the two chips at 360.
    placeholder: context.l10n.common_search,
    tone: LoopSearchTone.square,
    inkKey: const ValueKey<String>('square-community-search'),
    onTap: onTap,
  );
}

class _PinnedChips extends SliverPersistentHeaderDelegate {
  const _PinnedChips({required this.child});

  final Widget child;

  /// Above and below the line of controls.
  static const double inset = 6;

  /// The 52 search field (decision 0229) and its insets.
  static const double height = squareCommunityControlHeight + inset * 2;

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

  static Map<CommunityMembershipFilter, String> get _membershipLabels =>
      <CommunityMembershipFilter, String>{
        CommunityMembershipFilter.all: LoopL10n.current.common_all,
        CommunityMembershipFilter.joined:
            LoopL10n.current.square_communityListJoined,
      };

  @override
  Widget build(BuildContext context) {
    // S350a · decision 0274: a compact two-word track beside the search
    // field, as tall as the field, the chosen word the solid Purple choice.
    // Each word is as wide as itself, so 「我加入的」 is never cut.
    // Decision 0277: two Figma filter chips (54 × 32 in a 44 target) beside
    // the 44 field, 8 apart; no track.
    return SizedBox(
      key: const ValueKey<String>('square-community-chips'),
      height: squareCommunityControlHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final filter in CommunityMembershipFilter.values) ...<Widget>[
            if (filter.index > 0)
              const SizedBox(width: LoopSpacing.chipSpacing),
            LoopFilterChip(
              key: ValueKey<String>('square-filter-${filter.wireName}'),
              label: _membershipLabels[filter]!,
              selected: filter == membership,
              onSelected: () => onMembership(filter),
            ),
          ],
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
    LoopL10n.current.square_communityListSquareCommunitySubline(
      community.memberCount,
    ),
    ?ranked,
    if (symbol != null) '\$$symbol',
  ].join(LoopL10n.current.common_listSeparator);
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

/// The row's measures (S353a · decision 0278, docs/58 §5.8 / §3.2): rows on
/// the page in the page gutter, 86 high, a 56 logo at a 12 corner, a 1px
/// white 5 % hairline under each. [squareCommunityCardInset] keeps its name
/// for the pinned line's insets.
const double squareCommunityCardInset = LoopSpacing.page;

/// The pinned line's controls (S350a · decision 0274): the search field
/// and, beside it, the 全部 / 我加入的 track, as tall as the field — 44
/// since decision 0277 (the Figma's search field).
const double squareCommunityControlHeight = LoopTouch.searchField;
const double squareCommunityRowHeight = 86;
const double squareCommunityLogoSize = 56;
const double squareCommunityLogoRadius = LoopRadius.cardValue;
const double squareCommunityPillWidth = 54;
const double squareCommunityPillHeight = 28;
const double squareCommunityChipHeight = 16;
const double squareCommunityTokenLogoSize = 10;
const double squareCommunityMetaGap = 8;
const double squareCommunityTokenChipMaxWidth = 136;

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
      SquareMembershipAction.join => context.l10n.square_communityListJoin,
      SquareMembershipAction.joined => context.l10n.square_communityListJoined2,
      SquareMembershipAction.mine => context.l10n.square_communityListMine,
      SquareMembershipAction.pending =>
        context.l10n.square_communityListPending,
    };
    // S353a · decision 0278 (docs/58 §5.8): one row on the page, 86 high,
    // a hairline under it inside the page gutter.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: squareCommunityCardInset),
      child: Material(
        key: ValueKey<String>('square-community-card-$id'),
        type: MaterialType.transparency,
        shape: const Border(bottom: BorderSide(color: LoopColors.divider)),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label:
                    '${<String>[community.name, if (described) description, subline, if (label != null) communityLabelDisplay(label)].join(LoopL10n.current.common_listSeparator)}'
                    '$state',
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey<String>('square-community-open-$id'),
                  onTap: onOpen,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: squareCommunityRowHeight,
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
                                style: LoopType.body1,
                              ),
                              if (described) ...<Widget>[
                                const SizedBox(height: 1),
                                Text(
                                  description,
                                  key: ValueKey<String>(
                                    'square-community-description-$id',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LoopType.caption.copyWith(
                                    color: LoopColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              _SquareCommunityMeta(
                                communityId: id,
                                // docs/58 §5.8: the people mark and the
                                // number; the words stay in the spoken label.
                                members: loopGroupedFigure(
                                  community.memberCount.toString(),
                                ),
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
                padding: const EdgeInsets.only(left: 8),
                child: _MembershipCapsule(
                  communityId: id,
                  action: action,
                  joining: joining,
                  onJoin: onJoin,
                  onOpen: onOpen,
                ),
              ),
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
    // Decision 0264 (supplement): a 算力社区 always has its token, so the mark
    // rides inside the token chip as a Yellow bolt instead of a chip of its
    // own that a 390 line could never fit.
    final mark = label;
    final bolted = symbol != null && mark != null && squareIsMiningLabel(mark);
    final trailingLabel = bolted ? null : mark;
    return SizedBox(
      key: ValueKey<String>('square-community-meta-$id'),
      height: squareCommunityChipHeight,
      child: Row(
        children: <Widget>[
          const LoopIcon(
            'users',
            size: squareCommunityMetaIconSize,
            color: LoopColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            members,
            key: ValueKey<String>('square-community-members-$id'),
            maxLines: 1,
            softWrap: false,
            style: _squareMetaFacts,
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
                style: _squareMetaFacts,
              ),
            ),
          ],
          if (symbol case final String asset) ...<Widget>[
            const SizedBox(width: squareCommunityMetaGap),
            // On a narrow line the symbol is cut before the bolt or the logo.
            Flexible(
              flex: 3,
              child: ConstrainedBox(
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
                  color: LoopColors.textSecondary,
                  semanticsLabel: bolted
                      ? '\$$asset${LoopL10n.current.common_listSeparator}${communityLabelDisplay(mark)}'
                      : '\$$asset',
                  trailing: bolted
                      ? LoopIcon(
                          'bolt',
                          key: ValueKey<String>('square-community-bolt-$id'),
                          size: squareCommunityBoltSize,
                          color: LoopColors.yellow,
                        )
                      : null,
                ),
              ),
            ),
          ],
          // The label comes last and gives way first: whole when it fits,
          // cut after its first four characters at the least, otherwise left
          // off this line (the card's spoken label still carries it).
          if (trailingLabel case final String mark)
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

/// The facts line's words (S353a · docs/58 §5.8): the member count and the
/// token at 10 / 400 in textSecondary.
final TextStyle _squareMetaFacts = LoopType.metaSm;

/// The people mark before the member count (docs/58 §3.3: 12).
const double squareCommunityMetaIconSize = 12;

/// The narrowest a label chip may be drawn: its first four characters (and
/// an ellipsis when there is more) plus the chip's own padding and edge.
double squareMetaChipFloor(BuildContext context, String text) {
  final chars = text.characters;
  final shown = chars.length <= 4 ? text : '${chars.take(4)}…';
  final painter = TextPainter(
    text: TextSpan(text: shown, style: _squareMetaFacts),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width + squareMetaChipPadding * 2 + 2;
}

/// The bolt inside a 算力社区's token chip.
const double squareCommunityBoltSize = 10;

/// The operator's label that marks a 算力社区 (decision 0264 supplement).
/// Operators write it in Chinese, so it is matched as data against the zh
/// value whatever the reader's language (decision 0281: not copy).
String get squareMiningLabel =>
    lookupLoopLocalizations(LoopL10n.simplifiedChinese)
        .square_communityListSquareMiningLabel;

/// Whether [label] is the 算力社区 mark.
bool squareIsMiningLabel(String label) => label.trim() == squareMiningLabel;

const double squareMetaChipPadding = 5;

/// A 16-high outlined chip on the facts line (docs/58 §5.8): a 1px white 8 %
/// edge, round ends, an optional 10 logo, one 10 / 400 word.
class _SquareMetaChip extends StatelessWidget {
  const _SquareMetaChip({
    required this.text,
    required this.color,
    super.key,
    this.leading,
    this.trailing,
    this.semanticsLabel,
  });

  final String text;
  final Color color;
  final Widget? leading;

  /// A mark after the word (the 算力社区 bolt), 4 after it.
  final Widget? trailing;

  /// What the chip reads as; null reads [text].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel ?? text,
    excludeSemantics: true,
    child: Container(
      height: squareCommunityChipHeight,
      padding: EdgeInsets.only(
        left: leading == null ? squareMetaChipPadding : 3,
        right: squareMetaChipPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: LoopRadius.card,
        border: Border.all(color: LoopColors.buttonGhost),
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
              style: _squareMetaFacts.copyWith(color: color),
            ),
          ),
          if (trailing case final Widget mark) ...<Widget>[
            const SizedBox(width: 4),
            mark,
          ],
        ],
      ),
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
        context.l10n.square_communityListSwitch,
        true,
        joining ? null : onJoin,
      ),
      SquareMembershipAction.joined => (
        'joined',
        context.l10n.square_communityListMessage,
        false,
        onOpen,
      ),
      SquareMembershipAction.mine => (
        'mine',
        context.l10n.square_communityListSwitch2,
        false,
        onOpen,
      ),
      SquareMembershipAction.pending => (
        'pending',
        context.l10n.common_inReview,
        false,
        onOpen,
      ),
      SquareMembershipAction.none => ('none', '', false, null),
    };
    final word = joining ? context.l10n.square_communityListSwitch3 : label;
    // S353a · decision 0278 (docs/58 §5.8 / §5.20): the Figma's small 「加入」
    // — 54 × 28 at a 6 corner on white 8 %, the word 12 / 600 Yellow; 「已加入」
    // and the others the same key with the word in textSecondary.
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LoopColors.buttonGhost,
                borderRadius: LoopRadius.compactButton,
              ),
              child: Text(
                word,
                maxLines: 1,
                softWrap: false,
                style: LoopType.buttonXs.copyWith(
                  color: solid ? LoopColors.yellow : LoopColors.textSecondary,
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
        LoopSheetHeading(context.l10n.square_communityListLoopSheetHeading2),
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
                context.l10n.square_communityListBuild2,
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
              Text(
                context.l10n.square_communityListBuild3,
                style: LoopType.title,
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.square_communityListBuild4,
                style: LoopType.bodySm,
              ),
              const SizedBox(height: 14),
              LoopButtonPair(
                padded: false,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('square-community-apply'),
                    label: context
                        .l10n
                        .square_communityListSquareCommunityApplyLabel,
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
