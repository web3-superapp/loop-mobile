import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// S279 · decision 0237: the MEME home's tab memory key, in the same memory
/// the Tab pages' segments use, so the chosen tab outlives a trip to a
/// project page and a switch to another Tab.
const String launch2DeskTabMemoryKey = 'meme-desk';

/// The sentence a closed `launch2` capability is explained with.
String launch2CapabilityText(LoopCapabilityProjection capability) {
  if (capability.isUnobserved) {
    return capability.unreachable ? '暂时连不上 LOOP' : 'MEME v2 状态还没有读到';
  }
  return launch2ReasonText(
    capability.reasonCode ?? 'LAUNCH2_RUNTIME_UNAVAILABLE',
  );
}

/// MEME · 「v2 发射」 / 「已毕业」 (archetype `index`, layout `dashboard`,
/// decision 0139).
///
/// One row per instance in the OKX quote shape, read a page at a time as the
/// reader scrolls, pulled to re-read. An empty list is a line illustration,
/// a title and the one next step; a closed capability is one inline line,
/// never an empty list. The list ends on space, never on 「没有更多」.
///
/// Decision 0148: while the list is on screen (its route is the top one and
/// its tab is active) the first page is re-read every 60 s, and once more the
/// moment the reader comes back from a project page; both keep the rows
/// already scrolled to. A pull still starts the list over.
class Launch2ListSegment extends ConsumerStatefulWidget {
  const Launch2ListSegment({
    required this.scope,
    required this.onNavigate,
    super.key,
    this.onEmptyAction,
    this.tabTitle,
    this.actions = const <Widget>[],
  });

  final Launch2ListScope scope;

  /// S259 · decision 0217: the list is the MEME Tab itself (no segment row
  /// above it), so it draws its own bar under this title with [actions].
  /// `null` keeps the embedded segment body.
  final String? tabTitle;

  /// The bar's controls while [tabTitle] is set.
  final List<Widget> actions;
  final void Function(String location) onNavigate;

  /// The empty list's one next step (another segment of the MEME Tab).
  final VoidCallback? onEmptyAction;

  @override
  ConsumerState<Launch2ListSegment> createState() => _Launch2ListSegmentState();
}

class _Launch2ListSegmentState extends ConsumerState<Launch2ListSegment> {
  Timer? _poll;
  bool _visible = false;

  /// Something hid the list (a project page, another tab) since it was last
  /// on screen: coming back re-reads at once.
  bool _hidden = false;

  Launch2ListScope get scope => widget.scope;

  String get _keyBase => 'launch2-list-${scope.name}';

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S264: the home's atmosphere pieces decode before its first frame.
    if (!_precached && widget.tabTitle != null) {
      _precached = true;
      launch2PrecacheAtmosphere(context);
    }
    final visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _hidden = true;
      _stopPolling();
      return;
    }
    if (_hidden) {
      _hidden = false;
      scheduleMicrotask(_refresh);
    }
    _armPoll();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _armPoll() {
    _stopPolling();
    final interval = ref.read(launch2PollingProvider).listInterval;
    _poll = Timer.periodic(interval, (_) => _refresh());
  }

  void _refresh() {
    if (!mounted || !_visible || launch2ReadsBlocked(ref)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final provider = launch2ListControllerProvider(scope);
    final state = ref.read(provider);
    // Nothing read yet (the first read is the page's own) or a read already
    // running: the tick has nothing to add.
    if (state.value == null || state.busy || state.refreshing) return;
    unawaited(ref.read(provider.notifier).refresh());
    _refreshOverview();
    // S279: the 已毕业 tab's own list rides the same tick.
    if (_onGraduatedTab) {
      final graduated = ref.read(_graduatedProvider);
      if (graduated.value != null && !graduated.busy && !graduated.refreshing) {
        unawaited(ref.read(_graduatedProvider.notifier).refresh());
      }
    }
  }

  /// Decision 0163 §7.1: the overview rides the list's own refresh — the
  /// 60 s poll, the return from a project page and the pull — and has no
  /// timer of its own.
  ///
  /// Decision 0165: the campaign cards ride the same refresh.
  void _refreshOverview() {
    if (scope != Launch2ListScope.all) return;
    final overview = ref.read(launch2OverviewControllerProvider);
    if (!overview.busy && !overview.refreshing) {
      unawaited(ref.read(launch2OverviewControllerProvider.notifier).reload());
    }
    final campaigns = ref.read(launch2CampaignsControllerProvider);
    if (!campaigns.busy && !campaigns.refreshing) {
      unawaited(ref.read(launch2CampaignsControllerProvider.notifier).reload());
    }
  }

  Future<void> _pull(Launch2ListController controller) async {
    _refreshOverview();
    // S279: on the 已毕业 tab the pull re-reads that list too.
    if (_onGraduatedTab) {
      unawaited(controller.reload());
      await ref.read(_graduatedProvider.notifier).reload();
      return;
    }
    await controller.reload();
  }

  static final _graduatedProvider = launch2ListControllerProvider(
    Launch2ListScope.graduated,
  );

  /// Where each tab was scrolled to when the reader left it.
  final Map<Launch2DeskTab, double> _tabOffsets = <Launch2DeskTab, double>{};

  /// The tab the desk drew last; `null` before it drew one.
  Launch2DeskTab? _shownTab;

  bool get _onGraduatedTab =>
      scope == Launch2ListScope.all && _shownTab == Launch2DeskTab.graduated;

  void _openInstance(String instanceId) {
    widget.onNavigate(Launch2Route.instance(instanceId));
  }

  /// Moves to [next]: the tab being left keeps its scroll offset, and the
  /// one coming back opens where it was left. A tab not seen yet opens with
  /// the bar at the top of the page when the reader had scrolled past it, so
  /// the first row is never out of sight.
  void _selectTab(BuildContext context, Launch2DeskTab next) {
    final current = _shownTab;
    if (current == next) return;
    LoopHaptics.selection();
    final position = Scrollable.maybeOf(context)?.position;
    final bar = context.findRenderObject();
    double? anchor;
    if (position != null && position.hasPixels) {
      if (current != null) _tabOffsets[current] = position.pixels;
      if (bar is RenderBox && bar.attached) {
        final viewport = RenderAbstractViewport.maybeOf(bar);
        if (viewport != null) {
          final pinned = widget.tabTitle == null
              ? 0.0
              : LoopLayout.topbarHeight + MediaQuery.paddingOf(context).top;
          anchor = viewport.getOffsetToReveal(bar, 0).offset - pinned;
        }
      }
    }
    ref
        .read(loopTabSegmentMemoryProvider.notifier)
        .select(launch2DeskTabMemoryKey, next.index);
    if (position == null || !position.hasPixels) return;
    final saved = _tabOffsets[next];
    final now = position.pixels;
    _pendingJump = (
      tab: next,
      offset:
          saved ??
          (anchor != null && now > anchor ? math.max(0.0, anchor) : now),
    );
  }

  /// The offset [_selectTab] chose, applied after the frame that first lays
  /// the new tab out (the tab's own rows decide how far the page can go).
  ({Launch2DeskTab tab, double offset})? _pendingJump;

  /// The tab bar, so a jump finds the page's scroll position as it is after
  /// the new tab was laid out.
  final GlobalKey _tabsKey = GlobalKey(debugLabel: 'launch2-desk-tabs');

  void _applyPendingJump(Launch2DeskTab tab) {
    final pending = _pendingJump;
    if (pending == null || pending.tab != tab) return;
    _pendingJump = null;
    _jumpWhenLaidOut(pending.offset, 3);
  }

  /// Jumps [position] to [offset] once the page is long enough to hold it;
  /// the new tab's rows can take a frame or two to reach the viewport, so a
  /// short page is given [frames] more frames before the offset is clamped.
  void _jumpWhenLaidOut(double offset, int frames) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bar = _tabsKey.currentContext;
      if (!mounted || bar == null) return;
      final position = Scrollable.maybeOf(bar)?.position;
      if (position == null ||
          !position.hasPixels ||
          !position.hasContentDimensions) {
        return;
      }
      if (offset > position.maxScrollExtent && frames > 0) {
        _jumpWhenLaidOut(offset, frames - 1);
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      position.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    final blocked = launch2ReadsBlocked(ref);
    final provider = launch2ListControllerProvider(scope);
    final state = blocked ? null : ref.watch(provider);
    if (state != null) {
      launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    }
    final controller = ref.read(provider.notifier);
    // Decision 0163 §7.1 / §7.5: the overview, read with the first page.
    final overview = blocked || scope != Launch2ListScope.all
        ? null
        : ref.watch(launch2OverviewControllerProvider);
    if (overview != null) {
      launch2LoadOnce(
        ref,
        overview,
        () => ref.read(launch2OverviewControllerProvider.notifier).load(),
      );
    }
    // Decision 0165: the desk's campaign cards, read with the first page.
    // A failure (404, 503, an unreadable body) is no campaign.
    final campaigns = blocked || scope != Launch2ListScope.all
        ? null
        : ref.watch(launch2CampaignsControllerProvider);
    if (campaigns != null) {
      launch2LoadOnce(
        ref,
        campaigns,
        () => ref.read(launch2CampaignsControllerProvider.notifier).load(),
      );
    }
    return LoopDashboardPage(
      key: ValueKey<String>(_keyBase),
      archetype: LoopPageArchetype.listing,
      title:
          widget.tabTitle ?? (scope == Launch2ListScope.all ? 'v2 发射' : '已毕业'),
      embedded: widget.tabTitle == null,
      // S264 · decision 0220: the MEME home stands on the still wall, its
      // title over the wall crown.
      backdrop: widget.tabTitle == null
          ? null
          : const Launch2AtmosphereBackdrop(),
      titleField: widget.tabTitle == null
          ? null
          : Launch2AtmoTitle(title: widget.tabTitle!),
      actions: widget.tabTitle == null ? const <Widget>[] : widget.actions,
      updating: widget.tabTitle != null && (state?.refreshing ?? false),
      tabPage: true,
      onRefresh: blocked ? null : () => _pull(controller),
      sections: <Widget>[
        if (state == null)
          LoopInlineUnavailable(
            key: ValueKey<String>('$_keyBase-unavailable'),
            message: 'MEME v2 暂时不可用 · ${launch2CapabilityText(capability)}',
          )
        else
          ..._rows(
            state,
            controller,
            overview?.value,
            campaigns?.value?.items ?? const <Launch2DeskCampaign>[],
          ),
      ],
    );
  }

  List<Widget> _rows(
    LoopChainResourceState<Launch2InstancePage> state,
    Launch2ListController controller,
    Launch2Overview? overview,
    List<Launch2DeskCampaign> campaigns,
  ) {
    final page = state.value;
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('$_keyBase-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 6,
          rowHeight: memeCardHeight,
          leadingSize: memeCardLogoSize,
        ),
      ];
    }
    if (page == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: _keyBase,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '还没有 v2 项目',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    if (page.items.isEmpty) {
      final graduated = scope == Launch2ListScope.graduated;
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('$_keyBase-empty'),
          illustration: LoopIllustration.launchpad,
          title: graduated ? '还没有毕业的 v2 项目' : '还没有 v2 项目',
          message: graduated ? '内盘卖满后自动建官方池，会出现在这里' : 'NFT 预售开始后会出现在这里',
          action: widget.onEmptyAction == null
              ? null
              : LoopButton(
                  key: ValueKey<String>('$_keyBase-empty-action'),
                  // Decision 0217: the MEME Tab is the v2 desk alone; the
                  // graduated list's step goes back to it.
                  label: graduated ? '看正在发射的' : '看经典发射',
                  primary: true,
                  onPressed: widget.onEmptyAction,
                ),
        ),
      ];
    }
    final all = scope == Launch2ListScope.all;
    final stats = all ? overview?.stats : null;
    // A row whose stage time passed: the server says what it is now.
    void elapsed() => unawaited(controller.reload());
    return <Widget>[
      if (all)
        ..._desk(page, state, controller, overview, campaigns, elapsed)
      else ...<Widget>[
        for (final row in launch2ListOrder(page.items))
          Launch2InstanceTile(
            key: ValueKey<String>('launch2-tile-${row.instanceId}'),
            row: row,
            onTap: () => _openInstance(row.instanceId),
            onElapsed: elapsed,
          ),
        ..._footer(state, controller, _keyBase),
      ],
      // 战绩: the overview's figures; none read, none drawn. S326 · decision
      // 0256 (UX-004 ⑨): each cell has a second data line, and the page's
      // one source entry is a small 「(i) 来源」 beside the heading.
      if (stats != null) ...<Widget>[
        _StatsHeading(
          onSource: () => unawaited(
            showLoopProvenanceSheet(
              context,
              sources: const <String>['LOOP 链上索引'],
              observedAt: controller.valueObservedAt,
            ),
          ),
          semanticsLabel: LoopProvenanceLine(
            sources: const <String>['LOOP 链上索引'],
            observedAt: controller.valueObservedAt,
          ).text,
        ),
        KeyedSubtree(
          key: const ValueKey<String>('launch2-stats'),
          child: MemeStatFigures(
            stats: launch2DeskStats(stats),
            notes: launch2DeskStatNotes(
              stats,
              observedAt: overview?.observedAt,
            ),
          ),
        ),
      ] else
        LoopProvenanceLine(
          key: ValueKey<String>('$_keyBase-provenance'),
          sources: const <String>['LOOP 链上索引'],
          observedAt: controller.valueObservedAt,
        ),
    ];
  }

  /// The end of a list: the next page's sentinel, its failure, or the
  /// quiet end.
  List<Widget> _footer(
    LoopChainResourceState<Launch2InstancePage> state,
    Launch2ListController controller,
    String keyBase,
  ) {
    final cursor = state.value?.nextCursor;
    return <Widget>[
      if (controller.appendFailed && !state.busy)
        LoopInlineUnavailable(
          key: ValueKey<String>('$keyBase-more-failed'),
          message: '下一页没有读到',
          onRetry: () => unawaited(controller.loadMore()),
        )
      else if (cursor != null) ...<Widget>[
        LoopLoadMoreSentinel(
          key: ValueKey<String>('$keyBase-load-more'),
          cursor: cursor,
          onLoadMore: () => unawaited(controller.loadMore()),
        ),
        if (state.busy)
          LoopSkeleton(
            key: ValueKey<String>('$keyBase-loading-more'),
            type: LoopSkeletonType.priceRow,
            rows: 2,
            rowHeight: memeCardHeight,
            leadingSize: memeCardLogoSize,
          ),
      ] else
        MarketListEnd(key: ValueKey<String>('$keyBase-end')),
    ];
  }

  /// Decision 0164 · the prototype's Launch Desk over 「v2 发射」, in the
  /// S264 atmosphere (decision 0220): the banner pager, the Purple trade
  /// band, then — S279 · decision 0237 — the three tabs 「内盘 / 预告 /
  /// 已毕业」 and the one list the chosen tab holds. A record card stands at
  /// the top of its own tab and its row is not drawn twice.
  List<Widget> _desk(
    Launch2InstancePage page,
    LoopChainResourceState<Launch2InstancePage> state,
    Launch2ListController controller,
    Launch2Overview? overview,
    List<Launch2DeskCampaign> campaigns,
    VoidCallback onElapsed,
  ) {
    // Decision 0163: picked from the rows already read, never a request.
    final hero = launch2HeroRows(
      page.items.take(launch2HeroFirstPageRows).toList(growable: false),
    );
    final main = hero.isEmpty ? null : hero.first;
    final records = launch2DeskRecordRows(hero);
    final recordIds = <String>{for (final row in records) row.instanceId};
    final counts = launch2DeskTabCounts(
      launch2DeskCounts(page.items, overview?.stats),
    );
    final remembered = ref.watch(
      loopTabSegmentMemoryProvider.select(
        (memory) => memory[launch2DeskTabMemoryKey],
      ),
    );
    final tab = remembered == null
        ? launch2DefaultDeskTab(main, counts)
        : Launch2DeskTab.values[remembered.clamp(
            0,
            Launch2DeskTab.values.length - 1,
          )];
    _shownTab = tab;
    _applyPendingJump(tab);
    final activity = overview?.activity ?? const <Launch2Activity>[];
    final clock = ref.read(launch2ClockProvider);
    final band = activity.take(Launch2DeskTape.expanded).toList();
    return <Widget>[
      Launch2DeskPager(
        pages: launch2DeskPages(hero, campaigns: campaigns, now: clock()),
        chainId: page.items.first.chainId,
        onNavigate: widget.onNavigate,
        onElapsed: onElapsed,
      ),
      Builder(
        builder: (context) => Launch2TradeTicker(
          items: band,
          onOpenAll: () => unawaited(
            launch2ShowTradesSheet(
              context,
              items: band,
              now: clock,
              onNavigate: widget.onNavigate,
            ),
          ),
        ),
      ),
      Builder(
        key: _tabsKey,
        builder: (context) => Launch2DeskTabs(
          tabs: <Launch2DeskTabSpec>[
            for (final (entry, count) in counts)
              (
                id: entry.name,
                title: entry.title,
                count: count,
                selected: entry == tab,
              ),
          ],
          onSelected: (index) =>
              _selectTab(context, Launch2DeskTab.values[index]),
        ),
      ),
      // v3 (decision 0229): 16 from the tabs to what they choose between.
      const SizedBox(height: LoopSpacing.segmentGap),
      if (tab == Launch2DeskTab.graduated)
        ..._graduatedTab(onElapsed)
      else
        ..._readTab(
          tab,
          page,
          state,
          controller,
          records,
          recordIds,
          onElapsed,
        ),
      const SizedBox(height: 8),
    ];
  }

  /// 内盘 or 预告: the record cards of the tab, then its rows of the list
  /// read so far on one board; with nothing in it and no page left to read,
  /// the tab's own empty board.
  List<Widget> _readTab(
    Launch2DeskTab tab,
    Launch2InstancePage page,
    LoopChainResourceState<Launch2InstancePage> state,
    Launch2ListController controller,
    List<Launch2InstanceRow> records,
    Set<String> recordIds,
    VoidCallback onElapsed,
  ) {
    final cards = <Launch2InstanceRow>[
      for (final row in records)
        if (tab.holds(row)) row,
    ];
    // In the groups' order (铸造中 → 提前购 → 内盘 → 名单生成中 → 已暂停),
    // each group in the server's order.
    final rows = <Launch2InstanceRow>[
      for (final (_, members) in launch2GroupRows(<Launch2InstanceRow>[
        for (final row in launch2ListOrder(page.items))
          if (tab.holds(row) && !recordIds.contains(row.instanceId)) row,
      ]))
        ...members,
    ];
    final creatorOpen = launch2CreatorEntryVisible(ref);
    final more = page.nextCursor != null || controller.appendFailed;
    return <Widget>[
      for (final row in cards)
        Launch2DeskRecordCard(
          key: ValueKey<String>('launch2-desk-record-slot-${row.instanceId}'),
          row: row,
          onTap: () => widget.onNavigate(launch2HeroLocation(row)),
          onElapsed: onElapsed,
        ),
      if (rows.isNotEmpty)
        Launch2Board(
          key: ValueKey<String>('launch2-board-${tab.name}'),
          children: <Widget>[
            for (final row in rows)
              Launch2BoardRow(
                key: ValueKey<String>('launch2-tile-${row.instanceId}'),
                row: row,
                onTap: () => _openInstance(row.instanceId),
                onElapsed: onElapsed,
              ),
          ],
        )
      else if (cards.isEmpty && !more)
        if (tab == Launch2DeskTab.upcoming)
          Launch2UpcomingEmpty(
            onLaunch: creatorOpen
                ? () => widget.onNavigate(Launch2CreatorRoute.createPath)
                : null,
          )
        else
          const LoopAtmoEmpty(
            key: ValueKey<String>('launch2-live-empty'),
            message: '现在没有铸造或内盘中的项目，开售后会出现在这里',
            crownKey: ValueKey<String>('launch2-live-empty-crown'),
          ),
      ..._footer(state, controller, _keyBase),
    ];
  }

  /// 已毕业: the `stage=graduated` list, read when the tab is first opened,
  /// a page at a time like the desk's own.
  List<Widget> _graduatedTab(VoidCallback onElapsed) {
    final state = ref.watch(_graduatedProvider);
    launch2LoadOnce(
      ref,
      state,
      () => ref.read(_graduatedProvider.notifier).load(),
    );
    final controller = ref.read(_graduatedProvider.notifier);
    const keyBase = 'launch2-list-graduated';
    final page = state.value;
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return const <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('$keyBase-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 4,
          rowHeight: memeCardHeight,
          leadingSize: memeCardLogoSize,
        ),
      ];
    }
    if (page == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: keyBase,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '还没有毕业的 v2 项目',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    if (page.items.isEmpty) {
      return const <Widget>[
        LoopAtmoEmpty(
          key: ValueKey<String>('launch2-graduated-empty'),
          message: '还没有毕业的 v2 项目，内盘卖满后自动建官方池，会出现在这里',
          crownKey: ValueKey<String>('launch2-graduated-empty-crown'),
        ),
      ];
    }
    void elapsed() {
      onElapsed();
      unawaited(controller.reload());
    }

    return <Widget>[
      Launch2Board(
        key: const ValueKey<String>('launch2-board-graduated'),
        children: <Widget>[
          for (final row in launch2ListOrder(page.items))
            Launch2BoardRow(
              key: ValueKey<String>('launch2-tile-${row.instanceId}'),
              row: row,
              onTap: () => _openInstance(row.instanceId),
              onElapsed: elapsed,
            ),
        ],
      ),
      ..._footer(state, controller, keyBase),
    ];
  }
}

/// The order a v2 list draws its rows in (decision 0142): the server's own
/// order (newest activation first), except that `closed_no_holders` rows —
/// terminal, never tradable — sink below every other row read so far, in
/// their own server order. The 「已毕业」 list is `stage=graduated` and never
/// holds one. A later page's live rows therefore land above the closed ones
/// already on screen.
List<Launch2InstanceRow> launch2ListOrder(List<Launch2InstanceRow> rows) {
  if (!rows.any((row) => row.stage == Launch2Stage.closedNoHolders)) {
    return rows;
  }
  return <Launch2InstanceRow>[
    for (final row in rows)
      if (row.stage != Launch2Stage.closedNoHolders) row,
    for (final row in rows)
      if (row.stage == Launch2Stage.closedNoHolders) row,
  ];
}

/// 「战绩」 with the page's one source entry at its right: the section title
/// and a small 「(i) 来源」 on one line (S326 · decision 0256).
class _StatsHeading extends StatelessWidget {
  const _StatsHeading({required this.onSource, required this.semanticsLabel});

  final VoidCallback onSource;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('launch2-stats-heading'),
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      const Expanded(child: LoopLabel('战绩')),
      Padding(
        padding: const EdgeInsets.only(
          right: LoopSpacing.page - 4,
          bottom: LoopSpacing.sectionBottom - 12,
        ),
        child: LoopInfoTrigger(
          key: const ValueKey<String>('launch2-stats-source'),
          semanticsLabel: '$semanticsLabel，查看数据来源说明',
          onTap: onSource,
        ),
      ),
    ],
  );
}
