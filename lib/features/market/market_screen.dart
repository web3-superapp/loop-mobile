import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `market` · the行情 tab.
///
/// Every block reads its own state: the Watchlist, the trending ordering, new
/// pairs and smart money each fail independently, so one missing provider
/// never blanks the page.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key, this.onNavigate});

  final void Function(String location)? onNavigate;

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

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
    final watchlist = overview?.watchlist;
    final watchlistCount = watchlist is MarketWatchlistAvailable
        ? watchlist.items.length
        : null;
    // Mining, where 行情 touches it: the rules answer the Mining module
    // already reads. No request type of this page's own, and a weight it
    // cannot find is left off the row.
    final miningRules = watchMarketMiningRules(ref);
    final signal = MarketSignalSummary.of(watchlist);

    return LoopDashboardPage(
      key: const ValueKey<String>('market-screen'),
      archetype: LoopPageArchetype.listing,
      title: '行情',
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
      // folio.
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('market-capability-block'),
              title: '行情模块当前不可用',
              capability: capability,
              fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
            )
          : null,
      // `.topbar .tool-btn`: the prototype frames the search control and puts
      // 自选 in a text pill beside it. Two bare glyphs carried neither the
      // hit area nor the visual weight (audit 2026-09-21 §G.1).
      framedTools: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('market-search-action'),
          icon: 'search',
          label: '打开全局搜索',
          framed: true,
          onPressed: () => _open('/search'),
        ),
        LoopSeg(
          key: const ValueKey<String>('market-watchlist-action'),
          label: '自选',
          selected: false,
          onSelected: () => _open('/market/watchlist'),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('market-folio'),
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MARKET SIGNALS',
        // `.folio-heading` states a reading, never the page's own name: the
        // prototype's 「PEPE 领涨 +12.4%」 against LOOP's 「行情信号」, which
        // turned the hero into a second title bar (audit 2026-09-21 §D item
        // 1). The reading is the leader of the rows this block actually
        // holds — the overview sends the rows it chose, not the whole
        // Watchlist — and it is omitted whenever no 24h change was readable.
        heading: overview == null ? '行情暂时读不到' : signal.heading,
        caption: overview == null
            ? '行情暂时读不到，这里不显示数字。'
            : signal.caption ??
                  '每个数字都标注出处和时间 · '
                      '本次读取于 ${loopRelativeTime(overview.observedAt)}',
        // `.folio-stamp` carries a settled figure, not the module's name.
        stamp: signal.stamp,
      ),
      sections: <Widget>[
        if (!state.isReady || overview == null)
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
        else ...<Widget>[
          LoopLabel(
            watchlistCount == null ? '自选' : '自选 · 这一页 $watchlistCount 条',
          ),
          _WatchlistBlock(
            block: overview.watchlist,
            miningRules: miningRules,
            onOpenAsset: (assetId) => _open(MarketAssetRoute.token(assetId)),
            onManage: () => _open('/market/watchlist'),
            onAdd: () => _open('/market/new'),
          ),
          const LoopLabel('趋势'),
          _TrendingBlock(
            block: overview.trending,
            miningRules: miningRules,
            onOpenAsset: (assetId) => _open(MarketAssetRoute.token(assetId)),
          ),
          const LoopLabel('发现'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('market-new-pairs-entry'),
                title: '新币发现',
                // `available` says the new-pairs fact is readable right now,
                // and `omittedCount` says how much of it the page cannot
                // list. A provider that is on but unreadable arrives here as
                // unavailable, under the same reason code that page reports.
                subtitle: switch (overview.newPairs) {
                  MarketOverviewNewPairsAvailable(
                    omittedCount: final omitted,
                  ) =>
                    omitted > 0
                        ? '已登记的池与新交易对，均标注出处 · 另有 $omitted 条数据无法解析'
                        : '已登记的池与新交易对，均标注出处',
                  MarketOverviewNewPairsUnavailable(
                    reasonCode: final reasonCode,
                  ) =>
                    loopReasonCodeText(reasonCode),
                },
                subtitleMaxLines: 2,
                trailingBadge:
                    overview.newPairs is MarketOverviewNewPairsUnavailable
                    ? const LoopBadge('不可用')
                    : null,
                onTap: () => _open('/market/new'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('market-smart-money-entry'),
                title: '聪明钱追踪',
                subtitle: loopReasonCodeText(overview.smartMoney.reasonCode),
                trailingBadge: const LoopBadge('不可用'),
                onTap: () => _open('/market/smart-money'),
              ),
            ],
          ),
          MarketBlockProvenance(
            observedAt: overview.observedAt,
            prefix: '本页事实',
          ),
          const LoopNotice(
            key: ValueKey<String>('market-truth-notice'),
            title: '不只看价格',
            body: 'LOOP 只显示标注了出处和时间的数据，不给评分、评级或结论。读不到时会说明原因，不会显示 0。',
          ),
        ],
      ],
    );
  }
}

/// The reading the 行情 hero states, derived from the rows it already holds.
///
/// Every figure here is a count or a copy of one row's own 24h change: the
/// page computes no price, no average and no ordering of its own, and a row
/// whose change was not readable is counted as unread rather than as flat.
@immutable
final class MarketSignalSummary {
  const MarketSignalSummary({
    required this.heading,
    required this.caption,
    required this.stamp,
  });

  factory MarketSignalSummary.of(MarketWatchlistBlock? block) {
    if (block is! MarketWatchlistAvailable || block.items.isEmpty) {
      return const MarketSignalSummary(
        heading: '自选里还没有资产',
        caption: null,
        stamp: null,
      );
    }
    final items = block.items;
    MarketAssetRow? leader;
    var up = 0;
    var down = 0;
    var unread = 0;
    for (final row in items) {
      final change = row.priceChange24h.value;
      if (change == null || !row.priceChange24h.isAvailable) {
        unread += 1;
        continue;
      }
      if (change > Decimal.zero) {
        up += 1;
      } else if (change < Decimal.zero) {
        down += 1;
      }
      final best = leader?.priceChange24h.value;
      if (best == null || change > best) leader = row;
    }
    final stamp = '${items.length} WATCHED';
    final leaderChange = leader?.priceChange24h.value;
    final heading = leader == null || leaderChange == null
        ? '${items.length} 个自选 · 涨跌读不到'
        : leaderChange > Decimal.zero
        ? '${leader.displayName} 领涨 ${loopFormatPercent(leaderChange)}'
        : '${items.length} 个自选没有上涨';
    final caption = <String>[
      '${items.length} 个自选',
      if (up > 0 || down > 0) '$up 涨 $down 跌',
      if (unread > 0) '$unread 项涨跌读不到',
    ].join(' · ');
    return MarketSignalSummary(
      heading: heading,
      caption: '$caption。',
      stamp: stamp,
    );
  }

  final String heading;
  final String? caption;
  final String? stamp;
}

class _WatchlistBlock extends StatelessWidget {
  const _WatchlistBlock({
    required this.block,
    required this.miningRules,
    required this.onOpenAsset,
    required this.onManage,
    required this.onAdd,
  });

  final MarketWatchlistBlock block;
  final LaunchResourceState<MiningRules> miningRules;
  final void Function(String assetId) onOpenAsset;
  final VoidCallback onManage;

  /// Opens a page that lists assets, so the star is one tap away.
  final VoidCallback onAdd;

  /// The row that answers 「在哪儿增加自选」.
  ///
  /// C-30 (8): the empty state named the star and nothing on screen led to a
  /// page that has one. Adding is a write on the token page — the list has no
  /// add of its own — so this row is a route to an asset list, and it says so
  /// instead of pretending the tap adds anything.
  static LoopRecordRow addRow(VoidCallback onTap) => LoopRecordRow(
    key: const ValueKey<String>('market-watchlist-add'),
    title: '添加自选资产',
    subtitle: '打开代币页，点右上角星标 · 「趋势」和「新币发现」都能打开代币页',
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketWatchlistUnavailable(reasonCode: final reasonCode):
        // Nothing may be added to a list that could not be read: the write
        // would have no list to land in, and the row would promise one.
        return LoopUnavailableCard(
          key: const ValueKey<String>('market-watchlist-unavailable'),
          label: '自选行情不可用',
          reasonCode: reasonCode,
        );
      case MarketWatchlistAvailable(items: final items):
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopEmpty(
                key: const ValueKey<String>('market-watchlist-empty'),
                message: '还没有自选资产',
                reason: '在代币页点右上角星标加入自选，这里会显示它们的价格事实。',
                action: LoopButton(label: '管理自选', onPressed: onManage),
              ),
              LoopRecordGroup(rows: <LoopRecordRow>[addRow(onAdd)]),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < items.length; index += 1)
                  marketAssetRow(
                    items[index],
                    miningWeight: marketMiningWeightFor(
                      miningRules,
                      items[index].assetId,
                    ),
                    sparkline: MarketRowSparkline(
                      assetId: items[index].assetId,
                    ),
                    onTap: () => onOpenAsset(items[index].assetId),
                  ),
                addRow(onAdd),
              ],
            ),
            // The row's own source and observation time moved off its second
            // line, so the block still names both — once, for the rows it
            // just listed.
            MarketBlockProvenance.ofRows(
              key: const ValueKey<String>('market-watchlist-provenance'),
              rows: items,
            ),
          ],
        );
    }
  }
}

class _TrendingBlock extends StatelessWidget {
  const _TrendingBlock({
    required this.block,
    required this.miningRules,
    required this.onOpenAsset,
  });

  final MarketTrendingBlock block;
  final LaunchResourceState<MiningRules> miningRules;
  final void Function(String assetId) onOpenAsset;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketTrendingUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('market-trending-unavailable'),
          label: '趋势列表不可用',
          reasonCode: reasonCode,
        );
      case MarketTrendingAvailable(items: final items, rules: final rules):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (items.isEmpty)
              const LoopEmpty(
                key: ValueKey<String>('market-trending-empty'),
                message: '暂时没有可排序的资产',
                reason: '还没有可以显示成交量的资产。',
              )
            else
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  for (final row in items)
                    marketAssetRow(
                      row,
                      miningWeight: marketMiningWeightFor(
                        miningRules,
                        row.assetId,
                      ),
                      sparkline: MarketRowSparkline(assetId: row.assetId),
                      onTap: () => onOpenAsset(row.assetId),
                    ),
                ],
              ),
            MarketBlockProvenance.ofRows(
              key: const ValueKey<String>('market-trending-provenance'),
              rows: items,
            ),
            LoopProvenanceFooter(
              key: const ValueKey<String>('market-trending-rules'),
              text: rules.orderingLabel,
            ),
          ],
        );
    }
  }
}
