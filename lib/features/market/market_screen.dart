import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// The four lists 行情 offers, in the approved design's order.
///
/// 热门 and 涨幅榜 are the **same** trending read under two orderings; neither
/// issues a request of its own and neither is a ranking LOOP publishes. 新币
/// is the new-pairs read, listed here and still reachable as its own page.
enum MarketTab {
  watchlist('自选'),
  trending('热门'),
  gainers('涨幅榜'),
  newPairs('新币');

  const MarketTab(this.label);

  final String label;
}

/// `market` · the 行情 tab.
///
/// A price list, at a price list's density (approved design 2026-09-23,
/// decision 0084). Every block reads its own state: the Watchlist, the
/// trending ordering, new pairs and smart money each fail independently, so
/// one missing provider never blanks the page.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({
    super.key,
    this.onNavigate,
    this.title = '行情',
    this.titleWidget,
    this.shortcuts = const [],
    this.filters = const [],
  });

  final String title;
  final Widget? titleWidget;
  final List<Widget> shortcuts;
  final List<Widget> filters;

  final void Function(String location)? onNavigate;

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  MarketTab _tab = MarketTab.watchlist;
  MarketSort _sort = MarketSort.volume;
  bool _descending = true;
  String _category = 'all';

  /// Whether this page drew the list as a skeleton. Only then does the list
  /// fade in when it lands (decision 0095).
  bool _sawSkeleton = false;

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  /// A second press on the live column reverses it; a press on another column
  /// takes it, largest first.
  void _sortBy(MarketSort key) => setState(() {
    if (_sort == key) {
      _descending = !_descending;
      return;
    }
    _sort = key;
    _descending = true;
  });

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final mode = ref.watch(marketReadGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(marketOverviewControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(marketOverviewControllerProvider.notifier).load());
        }
      });
    }

    final overview = state.value;
    if (!blocked &&
        overview == null &&
        state.phase == LoopChainViewPhase.loading) {
      _sawSkeleton = true;
    }
    final controller = ref.read(marketOverviewControllerProvider.notifier);
    // Mining, where 行情 touches it: the rules answer the Mining module
    // already reads. No request type of this page's own, and a weight it
    // cannot find is left off the row.
    final miningRules = watchMarketMiningRules(ref);

    final pageBlock = blocked
        ? LoopCapabilityPageBlock.of(
            key: const ValueKey<String>('market-capability-block'),
            title: '行情模块当前不可用',
            capability: capability,
            fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
          )
        : null;

    return LoopDashboardPage(
      key: const ValueKey<String>('market-screen'),
      archetype: LoopPageArchetype.listing,
      title: widget.title,
      titleWidget: widget.titleWidget,
      tabPage: true,
      // A re-read over an overview the page already shows is marked, not
      // replaced by a skeleton.
      updating: state.refreshing,
      // Pull to re-read the overview. The Watchlist, the trending ordering and
      // the discovery entries arrive in one read, so one gesture refreshes the
      // page without replacing what it already shows.
      onRefresh: () =>
          ref.read(marketOverviewControllerProvider.notifier).reload(),
      // A closed capability is not an empty section: the page has nothing at
      // all, so it renders the whole-page block instead of a strip under the
      // list.
      block: pageBlock == null
          ? null
          : widget.shortcuts.isEmpty
          ? pageBlock
          : Column(
              children: [
                ...widget.shortcuts,
                Expanded(child: pageBlock),
              ],
            ),
      framedTools: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('market-more-action'),
          icon: 'compass',
          label: '更多行情',
          onPressed: _more,
        ),
        LoopIconButton(
          key: const ValueKey<String>('market-alerts-action'),
          icon: 'bell',
          label: '价格提醒',
          framed: true,
          onPressed: () => _open(MarketAssetRoute.alertsPath),
        ),
      ],
      // The approved design opens straight on the list: no hero. A 行情 tab
      // whose first screen is a Lime card states one row's change in 27pt and
      // pushes the other seven below the fold, which is the opposite of what
      // this page is for.
      sections: <Widget>[
        ...widget.shortcuts,
        LoopFreshnessStrip(
          key: const ValueKey<String>('market-freshness'),
          restoredAt: controller.restoredObservedAt,
          readAt: controller.valueObservedAt,
          refreshing: state.refreshing,
          refreshFailed: overview != null && state.failureKind != null,
          onRetry: () => unawaited(controller.reload()),
        ),
        MarketSearchField(onPressed: () => _open('/search')),
        ...widget.filters,
        MarketTabBar(
          key: const ValueKey<String>('market-tabs'),
          filter: true,
          labels: <String>[
            for (final tab in MarketTab.values.where(
              (tab) => tab != MarketTab.newPairs,
            ))
              tab.label,
          ],
          selectedIndex: _tab.index,
          onSelected: (index) => setState(() => _tab = MarketTab.values[index]),
        ),
        if (_tab != MarketTab.newPairs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  const LoopBadge('BSC'),
                  const SizedBox(width: 10),
                  for (final category in const <String, String>{
                    'all': '全部',
                    'native': '原生资产',
                    'token': '代币',
                  }.entries) ...<Widget>[
                    ChoiceChip(
                      key: ValueKey<String>('market-filter-${category.key}'),
                      label: Text(category.value),
                      selected: _category == category.key,
                      onSelected: (_) =>
                          setState(() => _category = category.key),
                      visualDensity: VisualDensity.standard,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        if (overview == null && state.phase == LoopChainViewPhase.loading)
          // Rows of the list's own fixed height, so nothing moves when the
          // prices land (decision 0095).
          const LoopSkeleton(
            key: ValueKey<String>('market-state-loading'),
            type: LoopSkeletonType.priceRow,
            rows: 6,
            rowHeight: marketRowHeight,
            leadingSize: marketRowLogoSize,
          )
        else if (!state.isReady || overview == null)
          LoopChainStateBlock(
            keyPrefix: 'market',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '暂时没有可展示的行情',
            emptyReason: '加入自选后，这里会显示价格，并标注出处。',
            onRetry: () => unawaited(
              ref.read(marketOverviewControllerProvider.notifier).reload(),
            ),
          )
        else
          ...switch (_tab) {
            MarketTab.watchlist => _assetTab(
              block: overview.watchlist,
              label: '自选',
              observedAt: overview.observedAt,
              miningRules: miningRules,
            ),
            MarketTab.trending || MarketTab.gainers => _assetTab(
              block: overview.trending,
              label: '热门',
              observedAt: overview.observedAt,
              miningRules: miningRules,
            ),
            MarketTab.newPairs => <Widget>[
              MarketNewPairsList(
                key: const ValueKey<String>('market-new-pairs-tab'),
                onOpenAsset: (assetId) =>
                    _open(MarketAssetRoute.token(assetId)),
                onOpenPage: () => _open('/market/new'),
              ),
            ],
          },
      ],
    );
  }

  void _more() => unawaited(
    showLoopSheet<void>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoopLabel('更多行情'),
          LoopRecordGroup(
            rows: [
              LoopRecordRow(
                title: '我的挖矿',
                leading: const LoopRowIcon(icon: 'mine-tab'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _open('/mining');
                },
              ),
              LoopRecordRow(
                title: '邀请好友',
                leading: const LoopRowIcon(icon: 'users'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _open('/profile/referral');
                },
              ),
              LoopRecordRow(
                title: '新币',
                leading: const LoopRowIcon(icon: 'chart'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _open('/market/new');
                },
              ),
              LoopRecordRow(
                title: '聪明钱',
                leading: const LoopRowIcon(icon: 'users'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _open('/market/smart-money');
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// One of the three asset tabs: the statistics line, the column header and
  /// the rows, in the order the reader's eye goes down them.
  List<Widget> _assetTab({
    required Object block,
    required String label,
    required DateTime observedAt,
    required LaunchResourceState<MiningRules> miningRules,
  }) {
    final String? reasonCode = switch (block) {
      MarketWatchlistUnavailable(reasonCode: final code) => code,
      MarketTrendingUnavailable(reasonCode: final code) => code,
      _ => null,
    };
    if (reasonCode != null) {
      return <Widget>[
        LoopUnavailableCard(
          key: ValueKey<String>(
            '${_tab == MarketTab.watchlist ? 'market-watchlist' : 'market-trending'}-unavailable',
          ),
          label: _tab == MarketTab.watchlist ? '自选行情不可用' : '热门列表不可用',
          reasonCode: reasonCode,
        ),
      ];
    }
    final allItems = switch (block) {
      MarketWatchlistAvailable(items: final rows) => rows,
      MarketTrendingAvailable(items: final rows) => rows,
      _ => const <MarketAssetRow>[],
    };
    final items = allItems
        .where(
          (row) => switch (_category) {
            'native' => row.assetId.endsWith(':native'),
            'token' => row.assetId.contains(':0x'),
            _ => true,
          },
        )
        .toList();
    final rules = block is MarketTrendingAvailable ? block.rules : null;
    final summary = MarketSignalSummary.of(items);

    if (items.isEmpty) {
      return <Widget>[
        if (_tab == MarketTab.watchlist) ...<Widget>[
          LoopEmpty(
            key: const ValueKey<String>('market-watchlist-empty'),
            message: allItems.isEmpty ? '还没有自选资产' : '当前分类没有资产',
            reason: '在代币页点右上角星标加入自选，这里会显示它们的价格事实。',
            action: LoopButton(
              label: '管理自选',
              onPressed: () => _open('/market/watchlist'),
            ),
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[_addRow(() => _open('/market/new'))],
          ),
        ] else
          LoopEmpty(
            key: const ValueKey<String>('market-trending-empty'),
            message: allItems.isEmpty ? '暂时没有可排序的资产' : '当前分类没有资产',
            reason: allItems.isEmpty ? '还没有可以显示成交量的资产。' : '切换「全部」查看其他资产。',
          ),
      ];
    }

    // 涨幅榜 is this list under one fixed ordering, so the header follows it
    // rather than contradicting it.
    final sort = _tab == MarketTab.gainers ? MarketSort.change : _sort;
    final descending = _tab == MarketTab.gainers ? true : _descending;
    final ordered = marketSortRows(items, sort: sort, descending: descending);

    return <Widget>[
      MarketStatsLine(
        key: const ValueKey<String>('market-stats'),
        label: label,
        total: items.length,
        up: summary.up,
        down: summary.down,
        flat: summary.flat,
        observedAt: observedAt,
      ),
      MarketColumnHeader(
        key: const ValueKey<String>('market-column-header'),
        sort: sort,
        descending: descending,
        onSelected: _tab == MarketTab.gainers ? (_) {} : _sortBy,
      ),
      LoopContentArrival(
        animate: _sawSkeleton,
        child: MarketAssetTileGroup(
          tiles: <Widget>[
            for (final row in ordered)
              MarketAssetTile(
                key: ValueKey<String>('market-asset-${row.assetId}'),
                row: row,
                miningWeight: marketMiningWeightFor(miningRules, row.assetId),
                sparkline: MarketRowSparkline(series: row.sparkline),
                onTap: () => _open(MarketAssetRoute.token(row.assetId)),
              ),
          ],
        ),
      ),
      if (_tab == MarketTab.watchlist)
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            _addRow(() => _open('/market/new')),
            LoopRecordRow(
              key: const ValueKey<String>('market-watchlist-manage'),
              title: '管理自选',
              subtitle: '排序、分组与移除',
              onTap: () => _open('/market/watchlist'),
            ),
          ],
        ),
      // The row's own source and observation time moved off its second line,
      // so the block still names both — once, for the rows it just listed.
      MarketBlockProvenance.ofRows(
        key: const ValueKey<String>('market-list-provenance'),
        rows: items,
      ),
      if (rules != null)
        LoopProvenanceFooter(
          key: const ValueKey<String>('market-trending-rules'),
          // The server's published order, and — when the reader has changed
          // it — that this device did the re-ordering.
          text: sort == MarketSort.volume && descending
              ? rules.orderingLabel
              : '${rules.orderingLabel} · 本页按${sort.label}'
                    '${descending ? '从高到低' : '从低到高'}重排（本机）',
        ),
    ];
  }

  /// The row that answers 「在哪儿增加自选」.
  ///
  /// C-30 (8): the empty state named the star and nothing on screen led to a
  /// page that has one. Adding is a write on the token page — the list has no
  /// add of its own — so this row is a route to an asset list, and it says so
  /// instead of pretending the tap adds anything.
  LoopRecordRow _addRow(VoidCallback onTap) => LoopRecordRow(
    key: const ValueKey<String>('market-watchlist-add'),
    title: '浏览代币',
    onTap: onTap,
  );
}

/// What the statistics line above a 行情 list counts.
///
/// Every figure here is a count of one row's own 24-hour change: the page
/// computes no price, no average and no ordering of its own. A row whose
/// change was not readable is counted nowhere — the row itself carries the
/// 读不到 block, which is where the reader is when they want to know about
/// that row.
@immutable
final class MarketSignalSummary {
  const MarketSignalSummary({
    required this.up,
    required this.down,
    required this.flat,
    required this.unread,
    required this.leader,
  });

  factory MarketSignalSummary.of(List<MarketAssetRow> items) {
    MarketAssetRow? leader;
    var up = 0;
    var down = 0;
    var flat = 0;
    var unread = 0;
    for (final row in items) {
      switch (MarketMove.of(row.priceChange24h)) {
        case MarketMove.up:
          up += 1;
        case MarketMove.down:
          down += 1;
        case MarketMove.flat:
          flat += 1;
        case MarketMove.unread:
          unread += 1;
          continue;
      }
      final change = row.priceChange24h.value!;
      final best = leader?.priceChange24h.value;
      if (best == null || change > best) leader = row;
    }
    return MarketSignalSummary(
      up: up,
      down: down,
      flat: flat,
      unread: unread,
      leader: leader,
    );
  }

  final int up;
  final int down;
  final int flat;

  /// Rows whose 24-hour change was not readable. Counted so a caller can say
  /// so if it has somewhere honest to say it; the statistics line does not.
  final int unread;

  /// The row with the largest readable rise, or `null`.
  final MarketAssetRow? leader;
}

/// Orders [rows] for the reader's chosen column.
///
/// A row missing the figure being sorted on keeps the server's own relative
/// order and sinks to the end: it is not a zero, and promoting it to the top
/// of a descending column would read as the largest value there is.
List<MarketAssetRow> marketSortRows(
  List<MarketAssetRow> rows, {
  required MarketSort sort,
  required bool descending,
}) {
  Decimal? key(MarketAssetRow row) => switch (sort) {
    MarketSort.volume => row.volume24h?.value,
    MarketSort.price => row.price.isAvailable ? row.price.value : null,
    MarketSort.change =>
      row.priceChange24h.isAvailable ? row.priceChange24h.value : null,
  };
  final indexed = <(int, MarketAssetRow)>[
    for (var index = 0; index < rows.length; index += 1) (index, rows[index]),
  ];
  indexed.sort((a, b) {
    final left = key(a.$2);
    final right = key(b.$2);
    if (left == null && right == null) return a.$1.compareTo(b.$1);
    if (left == null) return 1;
    if (right == null) return -1;
    final compared = left.compareTo(right);
    if (compared != 0) return descending ? -compared : compared;
    return a.$1.compareTo(b.$1);
  });
  return <MarketAssetRow>[for (final entry in indexed) entry.$2];
}
