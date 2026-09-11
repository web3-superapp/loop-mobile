import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
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
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('market-search-action'),
          icon: 'search',
          label: '打开全局搜索',
          onPressed: () => _open('/search'),
        ),
        LoopIconButton(
          key: const ValueKey<String>('market-watchlist-action'),
          icon: 'star',
          label: '管理自选',
          onPressed: () => _open('/market/watchlist'),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('market-folio'),
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MARKET SIGNALS',
        heading: watchlistCount == null ? '行情信号' : '$watchlistCount 个自选资产',
        caption: overview == null
            ? '行情暂时读不到，这里不显示数字。'
            : '每个数字都标注出处和时间 · '
                  '本次读取于 ${loopRelativeTime(overview.observedAt)}',
        stamp: watchlistCount == null ? null : '$watchlistCount WATCHED',
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
          const LoopLabel('自选'),
          _WatchlistBlock(
            block: overview.watchlist,
            onOpenAsset: (assetId) => _open(MarketAssetRoute.token(assetId)),
            onManage: () => _open('/market/watchlist'),
          ),
          const LoopLabel('趋势'),
          _TrendingBlock(
            block: overview.trending,
            onOpenAsset: (assetId) => _open(MarketAssetRoute.token(assetId)),
          ),
          const LoopLabel('发现'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('market-new-pairs-entry'),
                title: '新币发现',
                subtitle: overview.newPairsAvailable
                    ? '已登记的池与新交易对，均标注出处'
                    : loopReasonCodeText(overview.newPairsReasonCode),
                trailingBadge: overview.newPairsAvailable
                    ? null
                    : const LoopBadge('不可用'),
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

class _WatchlistBlock extends StatelessWidget {
  const _WatchlistBlock({
    required this.block,
    required this.onOpenAsset,
    required this.onManage,
  });

  final MarketWatchlistBlock block;
  final void Function(String assetId) onOpenAsset;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketWatchlistUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('market-watchlist-unavailable'),
          label: '自选行情不可用',
          reasonCode: reasonCode,
        );
      case MarketWatchlistAvailable(items: final items):
        if (items.isEmpty) {
          return LoopEmpty(
            key: const ValueKey<String>('market-watchlist-empty'),
            message: '还没有自选资产',
            reason: '在代币页点星标加入自选，这里会显示它们的价格事实。',
            action: LoopButton(label: '管理自选', onPressed: onManage),
          );
        }
        return LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (final row in items)
              marketAssetRow(row, onTap: () => onOpenAsset(row.assetId)),
          ],
        );
    }
  }
}

class _TrendingBlock extends StatelessWidget {
  const _TrendingBlock({required this.block, required this.onOpenAsset});

  final MarketTrendingBlock block;
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
                    marketAssetRow(row, onTap: () => onOpenAsset(row.assetId)),
                ],
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
