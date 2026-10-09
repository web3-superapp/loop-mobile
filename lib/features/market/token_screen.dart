import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `token` · one registry asset's facts, laid out the way the approved
/// reference lays a token out (Fomo, decision 0118).
///
/// The bar carries the ticker and the three tools (提醒 / 自选 / 分享); under
/// it one line names the asset and copies its address, then the price at the
/// display step over its 24-hour move, the market cap beside it, and the
/// chart — no card, about two fifths of the screen, a line by default and
/// candles on request, panned, pinched and read with a crosshair. 持有者 /
/// 动态 / 关于 sit under the chart and the 买入 / 卖出 bar stays pinned.
///
/// The route identity is the canonical `assetId`; a missing or malformed one
/// fails closed instead of substituting another asset. Every figure carries
/// its source and observation time, and the Swap entry point is rendered only
/// when the server says `capability.swappable` — which it never does before
/// D15.
class TokenDetailScreen extends ConsumerStatefulWidget {
  const TokenDetailScreen({
    required this.assetId,
    super.key,
    this.onNavigate,
    this.onBack,
  });

  final String? assetId;
  final void Function(String location)? onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

/// The three tabs under the chart, in the reference's order.
enum TokenSectionTab {
  holders('持有者'),
  activity('动态'),
  about('关于');

  const TokenSectionTab(this.label);

  final String label;
}

class _TokenDetailScreenState extends ConsumerState<TokenDetailScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;
  TokenSectionTab _tab = TokenSectionTab.holders;

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  /// Adds or removes this asset, then says which of the two happened. A
  /// refusal names the server's own reason; nothing on screen moves unless the
  /// server answered with the document that now exists.
  Future<void> _toggleWatchlist(String assetId) async {
    final result = await ref
        .read(watchlistMembershipControllerProvider(assetId).notifier)
        .toggle();
    if (!mounted) return;
    showWatchlistToggleToast(context, result);
  }

  /// Hands the asset's name and contract to the system share sheet. No
  /// figure goes with it: a price out of its page has no source beside it.
  Future<void> _share(String assetId, MarketAssetDetail? detail) async {
    final asset = detail?.asset.settled;
    final text = <String>[
      if (asset != null) '${loopAssetSymbolLabel(asset)} · ${asset.name}',
      if (asset?.address case final address?) '合约 $address' else assetId,
      '在 LOOP 查看行情',
    ].join('\n');
    final shown = await ref.read(loopTextShareProvider)(text);
    if (!mounted || shown) return;
    LoopToast.show(context, message: '系统分享暂时打不开', kind: LoopToastKind.warn);
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return LoopFocusPage(
        key: const ValueKey<String>('token-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这个资产',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('token-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的资产标识',
            reason: 'Token 页只接受规范的 CAIP assetId。未请求任何行情，也没有回退到其他资产。',
          ),
        ],
      );
    }

    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final mode = ref.watch(marketReadGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(marketAssetControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketAssetControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    // Decision 0101: the chart needs nothing from the asset read but the
    // assetId the route already carries, so it is asked for in the same round
    // trip instead of after the quote lands. Listening (not watching) holds
    // the read for the page without rebuilding the page on every candle state.
    if (!blocked) {
      final candles = marketCandlesControllerProvider(
        MarketCandleRequest(
          assetId: assetId,
          interval: _interval,
          limit: MarketCandleRequest.chartLimit,
        ),
      );
      ref.listen(candles, (_, _) {});
      if (ref.read(candles).phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) unawaited(ref.read(candles.notifier).load());
        });
      }
    }
    final detail = state.value;

    // The star is a write on a different resource, so it reads its own
    // capability and its own gateway mode: a Market outage must not claim the
    // asset is unwatched, and a Watchlist outage must not hide the price.
    final watchlistCapability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.watchlist),
    );
    final watchlistMode = ref.watch(watchlistGatewayProvider).mode;
    final membership = ref.watch(
      watchlistMembershipControllerProvider(assetId),
    );
    // `loopChainCapabilityBlocks` only exempts Preview from the capability
    // document; it says nothing about a production build with no transport.
    // The controller's own `unavailable` phase is that second answer, and both
    // close the star.
    final watchlistBlocked =
        loopChainCapabilityBlocks(watchlistMode, watchlistCapability) ||
        membership.phase == LoopChainViewPhase.unavailable;
    if (!watchlistBlocked && membership.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(watchlistMembershipControllerProvider(assetId).notifier)
                .load(),
          );
        }
      });
    }

    // Why 兑换 cannot be used has one answer, and it is the gate the wallet's
    // funds row and the swap page both read.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    // Mining, where 行情 touches it: the rules answer the Mining module
    // already reads; a weight it does not list is left off.
    final miningRules = watchMarketMiningRules(ref);
    final miningWeight = marketMiningWeightFor(miningRules, assetId);
    final swapBlockedReason = swapGate.isAvailable
        ? (detail?.capability.reasonCode ?? 'SWAP_MODULE_NOT_DELIVERED')
        : (swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE');

    // The chart takes about two fifths of the screen (decision 0118).
    final chartHeight = (MediaQuery.sizeOf(context).height * 0.4 - 96).clamp(
      200.0,
      420.0,
    );

    return LoopDashboardPage(
      key: ValueKey<String>('token-screen-$assetId'),
      onRefresh: () async {
        await Future.wait(<Future<void>>[
          ref.read(marketAssetControllerProvider(assetId).notifier).reload(),
          ref
              .read(
                marketCandlesControllerProvider(
                  MarketCandleRequest(
                    assetId: assetId,
                    interval: _interval,
                    limit: MarketCandleRequest.chartLimit,
                  ),
                ).notifier,
              )
              .reload(),
        ]);
      },
      archetype: LoopPageArchetype.record,
      // The two actions stay pinned to the foot of the page (decision 0086):
      // same single gate, same two labels. The bar is withheld while the page
      // has no facts at all.
      bottomBar: detail == null || detail.capability.blocksEntirePage
          ? null
          : MarketTradeBar(
              key: const ValueKey<String>('token-trade-bar'),
              tradable: detail.capability.swappable,
              onTrade: () => _open('/wallet/swap'),
            ),
      title: detail == null
          ? loopTruncatedAssetId(assetId)
          : marketAssetIdentityLabel(detail.asset),
      onBack: widget.onBack,
      updating: state.refreshing,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('token-alerts-action'),
          icon: 'bell',
          label: '价格提醒',
          onPressed: () => _open(MarketAssetRoute.alerts(assetId)),
        ),
        // The star is the whole "add to watchlist" path: it states membership
        // and toggles it. It never navigates.
        LoopIconButton(
          key: const ValueKey<String>('token-watchlist-action'),
          icon: 'star',
          label: watchlistBlocked ? '自选当前不可用' : membership.actionLabel,
          color: membership.isWatched ? LoopColors.lime : null,
          // An unread list has no on/off state to report; claiming
          // `false` would say the asset is not watched.
          toggled: watchlistBlocked || !membership.isKnown
              ? null
              : membership.isWatched,
          onPressed: watchlistBlocked || membership.busy
              ? null
              : () => unawaited(_toggleWatchlist(assetId)),
        ),
        LoopIconButton(
          key: const ValueKey<String>('token-share-action'),
          icon: 'share',
          label: '分享',
          onPressed: () => unawaited(_share(assetId, detail)),
        ),
      ],
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('token-capability-block'),
              title: '行情模块当前不可用',
              capability: capability,
              fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || detail == null)
          LoopChainStateBlock(
            keyPrefix: 'token',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '这个资产还没有可展示的事实',
            onRetry: () => unawaited(
              ref
                  .read(marketAssetControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else if (detail.capability.blocksEntirePage)
          LoopUnavailableCard(
            key: const ValueKey<String>('token-asset-blocked'),
            label: '该资产已被标记为不可展示',
            reasonCode: detail.capability.reasonCode ?? 'ASSET_BLOCKED',
          )
        else ...<Widget>[
          TokenIdentityLine(detail: detail, assetId: assetId),
          // Nothing could describe this contract for this request. The page
          // still stands — every figure below states its own reason — but it
          // names the address it asked about instead of an identity.
          if (detail.asset case final MarketAssetIdentityUnavailable identity)
            LoopInlineUnavailable(
              key: const ValueKey<String>('token-asset-unavailable'),
              message:
                  '${marketAssetUnavailableHeading(identity)} · '
                  '${loopReasonCodeText(identity.reasonCode)}',
              // The server said the asks are coming too fast. Asking again
              // now spends the next one for the same sentence, so the retry
              // is withheld while that is the reason.
              onRetry: _providerRateLimited(identity.reasonCode)
                  ? null
                  : () => unawaited(
                      ref
                          .read(marketAssetControllerProvider(assetId).notifier)
                          .reload(),
                    ),
            )
          else if (detail.capability.suppressesLiveFigures)
            LoopInlineUnavailable(
              key: const ValueKey<String>('token-live-suppressed'),
              message:
                  '链上读取暂时不可用 · ${loopReasonCodeText(detail.capability.reasonCode ?? 'BSC_CHAIN_RUNTIME_UNAVAILABLE')}',
            ),
          TokenPriceHeader(
            key: const ValueKey<String>('token-quote'),
            price: detail.price,
            change: detail.priceChange24h,
            marketCap: detail.marketCap,
          ),
          TokenCandleSection(
            assetId: assetId,
            interval: _interval,
            height: chartHeight,
            onIntervalChanged: (value) => setState(() => _interval = value),
            trailing: LoopIconButton(
              key: const ValueKey<String>('token-chart-expand'),
              icon: 'expand',
              label: '打开全屏图表',
              onPressed: () => _open(MarketAssetRoute.chart(assetId)),
            ),
          ),
          // 持有者 / 动态 / 关于. Switching a tab changes what is listed and
          // nothing else; 动态 reads its trades the first time it opens.
          MarketTabBar(
            key: const ValueKey<String>('token-section-tabs'),
            keyPrefix: 'token-tab',
            labels: <String>[
              for (final tab in TokenSectionTab.values) tab.label,
            ],
            selectedIndex: TokenSectionTab.values.indexOf(_tab),
            onSelected: (index) =>
                setState(() => _tab = TokenSectionTab.values[index]),
          ),
          const SizedBox(height: 8),
          ...switch (_tab) {
            TokenSectionTab.holders => _holderSections(detail),
            TokenSectionTab.activity => _tradeSections(assetId),
            TokenSectionTab.about => <Widget>[
              ..._aboutSections(assetId, detail, miningWeight: miningWeight),
              // The only gate for a Swap entry point. The backend pins it to
              // false until D15, so the bar's 买入 / 卖出 are drawn disabled
              // and this line says why.
              if (detail.capability.swappable)
                LoopButton(
                  key: const ValueKey<String>('token-swap-entry'),
                  label: '兑换',
                  primary: true,
                  block: true,
                  onPressed: () => _open('/wallet/swap'),
                )
              else
                LoopInlineUnavailable(
                  key: const ValueKey<String>('token-swap-unavailable'),
                  // A closed gate is the whole app's answer and outranks this
                  // asset's own.
                  message:
                      '买入、卖出与兑换当前不可用 · ${loopReasonCodeText(swapBlockedReason)}',
                ),
            ],
          },
        ],
      ],
    );
  }

  /// 持有者: the holder count, and the distribution LOOP cannot read yet.
  List<Widget> _holderSections(MarketAssetDetail detail) {
    final count = detail.holderCount;
    return <Widget>[
      Padding(
        key: const ValueKey<String>('token-holders-count'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          children: <Widget>[
            Text(
              '持有人数',
              style: LoopType.body.copyWith(color: LoopColors.text2),
            ),
            const Spacer(),
            Text(
              count.isAvailable
                  ? loopFormatDecimal(count.value!, maxFractionDigits: 0)
                  : loopReasonCodeSummaryText(count.reasonCode),
              style: count.isAvailable
                  ? LoopType.figureMd
                  : LoopType.caption.copyWith(color: LoopColors.text3),
            ),
          ],
        ),
      ),
      const LoopInlineUnavailable(
        key: ValueKey<String>('token-holders-distribution-unavailable'),
        icon: 'info',
        message: '持有人分布暂不可用',
      ),
      _factsProvenance(
        key: const ValueKey<String>('token-holders-provenance'),
        facts: <LoopFact>[count],
        prefix: '持有人数',
      ),
    ];
  }

  /// 动态: the indexed trades of the registered pool, a cursor page at a time
  /// as the reader scrolls. Each row is its own section so the list is built
  /// lazily and the next page is asked for only when its end comes into view.
  List<Widget> _tradeSections(String assetId) {
    final provider = marketTradesControllerProvider(assetId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(provider.notifier).load());
      });
    }
    final block = state.value?.trades;
    if (!state.isReady || block == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: 'token-trades',
          phase: state.phase,
          failureKind: state.failureKind,
          rows: 4,
          emptyMessage: '还没有成交',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    switch (block) {
      case MarketTradesUnavailable(reasonCode: final reasonCode):
        return <Widget>[
          LoopInlineUnavailable(
            key: const ValueKey<String>('token-trades-unavailable'),
            message: '成交记录暂时读不到 · ${loopReasonCodeText(reasonCode)}',
          ),
        ];
      case MarketTradesAvailable(:final items) when items.isEmpty:
        return <Widget>[
          const LoopEmptyState(
            key: ValueKey<String>('token-trades-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: '还没有成交',
            message: '这个池子最近还没有人交易',
            compact: true,
          ),
          _tradesProvenance(block),
        ];
      case MarketTradesAvailable(:final items, :final nextCursor):
        return <Widget>[
          for (final trade in items) TokenTradeRow(trade: trade),
          if (controller.appendFailed && !state.busy)
            LoopInlineUnavailable(
              key: const ValueKey<String>('token-trades-more-failed'),
              message: '下一页没有读到',
              onRetry: () => unawaited(controller.loadMore()),
            )
          else if (nextCursor != null) ...<Widget>[
            LoopLoadMoreSentinel(
              key: const ValueKey<String>('token-trades-load-more'),
              cursor: nextCursor,
              onLoadMore: () => unawaited(controller.loadMore()),
            ),
            if (state.busy)
              const LoopSkeleton(
                key: ValueKey<String>('token-trades-loading-more'),
                type: LoopSkeletonType.record,
                rows: 2,
              ),
          ] else
            const MarketListEnd(key: ValueKey<String>('token-trades-end')),
          _tradesProvenance(block),
        ];
    }
  }

  Widget _tradesProvenance(MarketTradesAvailable block) {
    final freshness = block.freshness;
    final lag = freshness.lagBlocks;
    return LoopProvenanceLine(
      key: const ValueKey<String>('token-trades-provenance'),
      sources: <String>[loopFactSourceLabel(block.source)],
      observedAt: freshness.observedAt,
      prefix:
          '索引高度 ${loopGroupedFigure(freshness.indexerBlockNumber.toString())}',
      detail: <String>[
        if (lag != null) '数据落后 ${loopGroupedFigure(lag.toString())} 块。',
        '成交来自已登记池的 Swap 事件。LOOP 不下发对手方地址，只标出哪一笔是你自己的钱包发起的。',
      ].join(''),
    );
  }

  /// 关于: what the asset is, its community, its pool and contract facts, and
  /// the notifications it raised.
  List<Widget> _aboutSections(
    String assetId,
    MarketAssetDetail detail, {
    required MarketMiningWeight? miningWeight,
  }) {
    final asset = detail.asset.settled;
    return <Widget>[
      const LoopLabel('简介'),
      MarketQuoteCells(
        key: const ValueKey<String>('token-about-cells'),
        cells: <MarketStatCell>[
          marketRangeCell('24h 高', detail.range24h, high: true),
          marketRangeCell('24h 低', detail.range24h, high: false),
          MarketStatCell.fact(
            '24h 成交额',
            detail.volume24h,
            formatter: loopFormatCompactFigure,
          ),
        ],
      ),
      MarketQuoteCells(
        key: const ValueKey<String>('token-about-cells-2'),
        cells: <MarketStatCell>[
          MarketStatCell.fact(
            '流动性',
            detail.liquidityUsd,
            formatter: loopFormatCompactFigure,
          ),
          MarketStatCell.fact(
            '完全稀释估值',
            detail.fdv,
            formatter: loopFormatCompactFigure,
          ),
          MarketStatCell.fact(
            '市值',
            detail.marketCap,
            formatter: loopFormatCompactFigure,
          ),
        ],
      ),
      if (asset != null)
        LoopKeyValue(
          key: const ValueKey<String>('token-about-contract'),
          label: '合约',
          value: asset.address == null
              ? '链上原生资产'
              : loopTruncatedAddress(asset.address!),
        ),
      _factsProvenance(
        key: const ValueKey<String>('token-facts-provenance'),
        facts: <LoopFact>[
          detail.volume24h,
          detail.liquidityUsd,
          detail.fdv,
          detail.marketCap,
        ],
      ),
      const LoopLabel('社区'),
      _CommunityBlock(
        block: detail.community,
        onOpenCommunity: (communityId) => _open(
          '/community/profile?id=${Uri.encodeQueryComponent(communityId)}',
        ),
      ),
      if (miningWeight != null)
        LoopPowerHint(
          key: const ValueKey<String>('token-mining-weight'),
          text: '挖矿权重',
          figure: miningWeight.label,
          onTap: () => _open('/mining'),
        ),
      const LoopLabel('池与合约事实'),
      TokenPoolAndContractFacts(
        pair: detail.primaryPair,
        security: detail.security,
      ),
      const LoopLabel('通知'),
      _TokenNotificationFeed(assetId: assetId),
    ];
  }

  static Widget _factsProvenance({
    required Key key,
    required List<LoopFact> facts,
    String? prefix,
  }) {
    final sources = <String>[];
    DateTime? oldest;
    var marked = false;
    for (final fact in facts) {
      if (!fact.isAvailable) continue;
      final source = fact.source;
      if (source != null) sources.add(loopFactSourceLabel(source));
      final at = fact.fetchedAt;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
      if (loopFactQualityMarker(fact.quality) != null) marked = true;
    }
    return LoopProvenanceLine(
      key: key,
      sources: sources,
      observedAt: oldest,
      prefix: <String>[?prefix, if (marked) '含延迟或折算的数值'].join(' · ').isEmpty
          ? null
          : <String>[?prefix, if (marked) '含延迟或折算的数值'].join(' · '),
      detail: '读不到的数值写明原因，不会显示 0。',
    );
  }
}

/// Whether the server's reason is the provider's own quota being spent.
///
/// A retry against it buys the same sentence and one fewer request, so the
/// surfaces that offer a retry hold it shut while this is the reason.
bool _providerRateLimited(String? reasonCode) =>
    reasonCode == 'MARKET_PROVIDER_RATE_LIMITED';

/// The line under the bar: the asset's mark, its name and its contract, and
/// a copy control for the address.
class TokenIdentityLine extends StatelessWidget {
  const TokenIdentityLine({
    required this.detail,
    required this.assetId,
    super.key,
  });

  final MarketAssetDetail detail;
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final asset = detail.asset.settled;
    final symbol = marketAssetIdentityLabel(detail.asset);
    final address = asset?.address;
    return Padding(
      key: const ValueKey<String>('token-identity'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: <Widget>[
          LoopTokenLogo(
            assetSymbol: symbol,
            logoUrl: detail.logoUrl,
            fallbackMonogram: symbol,
            size: 44,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              <String>[
                ?asset?.name,
                address == null
                    ? loopTruncatedAssetId(assetId)
                    : loopTruncatedAddress(address),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ),
          if (address != null)
            LoopIconButton(
              key: const ValueKey<String>('token-copy-address'),
              icon: 'copy',
              label: '复制合约地址',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (!context.mounted) return;
                LoopToast.show(context, message: '已复制合约地址');
              },
            ),
        ],
      ),
    );
  }
}

/// The price at the display step, the 24-hour move under it in rise / fall,
/// and the market cap on the right (decision 0118).
class TokenPriceHeader extends StatelessWidget {
  const TokenPriceHeader({
    required this.price,
    required this.change,
    required this.marketCap,
    super.key,
  });

  final LoopFact price;
  final LoopFact change;
  final LoopFact marketCap;

  /// The move restated in dollars: `price − price ÷ (1 + change/100)`. It is
  /// derived from the two figures beside it and from nothing else, and is
  /// left out whenever either was not read or the change is −100 %.
  static Decimal? absoluteMove(Decimal price, Decimal percent) {
    final hundred = Decimal.fromInt(100);
    final ratio =
        Decimal.one +
        (percent / hundred).toDecimal(scaleOnInfinitePrecision: 18);
    if (ratio == Decimal.zero) return null;
    final previous = (price / ratio).toDecimal(scaleOnInfinitePrecision: 8);
    return price - previous;
  }

  @override
  Widget build(BuildContext context) {
    final priceValue = price.isAvailable ? price.value : null;
    final changeValue = change.isAvailable ? change.value : null;
    final move = LoopPriceMove.of(changeValue);
    final absolute = priceValue == null || changeValue == null
        ? null
        : absoluteMove(priceValue, changeValue);
    final cap = marketCap.isAvailable ? marketCap.value : null;
    final marker = priceValue == null
        ? null
        : marketQuoteQualityMarker(price.quality);
    final moveText = changeValue == null
        ? '24h 涨跌${loopReasonCodeSummaryText(change.reasonCode)}'
        : <String>[
            if (absolute != null)
              '${move == LoopPriceMove.down
                      ? '▼'
                      : move == LoopPriceMove.up
                      ? '▲'
                      : ''} '
                  '${marketRowPrice(absolute < Decimal.zero ? -absolute : absolute)}'
                  ' (${marketMoveLabel(changeValue).replaceAll('▲ ', '').replaceAll('▼ ', '')})'
            else
              marketMoveLabel(changeValue),
            '24h',
          ].join(' · ').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (priceValue == null)
                  LoopInlineUnavailable(
                    key: const ValueKey<String>('token-price-unavailable'),
                    message:
                        '价格${loopReasonCodeSummaryText(price.reasonCode)}'
                        ' · ${loopReasonCodeText(price.reasonCode)}',
                    padding: EdgeInsets.zero,
                  )
                else
                  Text(
                    marketRowPrice(priceValue),
                    key: const ValueKey<String>('token-price'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.figureXl,
                  ),
                const SizedBox(height: 2),
                Text(
                  <String>[moveText, ?marker].join(' · '),
                  key: const ValueKey<String>('token-change'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureSm.copyWith(
                    color: changeValue == null ? LoopColors.text3 : move.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                cap == null
                    ? loopReasonCodeSummaryText(marketCap.reasonCode)
                    : loopFormatCompactFigure(cap),
                key: const ValueKey<String>('token-market-cap'),
                style: cap == null
                    ? LoopType.caption.copyWith(color: LoopColors.text3)
                    : LoopType.figureMd,
              ),
              const SizedBox(height: 2),
              Text(
                '市值',
                style: LoopType.captionSm.copyWith(color: LoopColors.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One indexed swap on 动态: direction in rise / fall, the two amounts, and
/// when it happened.
class TokenTradeRow extends StatelessWidget {
  TokenTradeRow({required this.trade})
    : super(key: ValueKey<String>('trade-${trade.tradeId}'));

  final MarketTrade trade;

  @override
  Widget build(BuildContext context) {
    final buy = trade.direction == MarketTradeDirection.buy;
    final move = buy ? LoopPriceMove.up : LoopPriceMove.down;
    final reorged = trade.status == LoopConfirmationStatus.reorged;
    return Semantics(
      label: <String>[
        if (trade.isOwn) '我',
        buy ? '买入' : '卖出',
        '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} ${trade.quoteSymbol}',
        loopFormatDecimal(trade.amountAsset),
        loopConfirmationLabel(trade.status),
        loopRelativeTime(trade.blockTimestamp),
      ].join('，'),
      excludeSemantics: true,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LoopColors.line)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              child: Text(
                buy ? '买入' : '卖出',
                style: LoopType.title.copyWith(color: move.color),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} ${trade.quoteSymbol}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.figure,
                  ),
                  Text(
                    <String>[
                      if (trade.isOwn) '我',
                      loopRelativeTime(trade.blockTimestamp),
                      loopConfirmationLabel(trade.status),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                  ),
                ],
              ),
            ),
            if (reorged) ...<Widget>[
              const LoopBadge('已回滚', kind: LoopBadgeKind.down),
              const SizedBox(width: 6),
            ],
            Text(
              loopFormatDecimal(trade.amountAsset, maxFractionDigits: 4),
              maxLines: 1,
              style: LoopType.figureSm.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chart block shared by `token` and `chart-full`: a toolbar (line or
/// candles, MA, VOL), the chart, the interval chips and one source line.
class TokenCandleSection extends ConsumerStatefulWidget {
  const TokenCandleSection({
    required this.assetId,
    required this.interval,
    required this.onIntervalChanged,
    super.key,
    this.trailing,
    this.height = 280,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final ValueChanged<LoopCandleInterval> onIntervalChanged;

  /// A control at the end of the interval row (the full-screen glyph).
  final Widget? trailing;
  final double height;

  @override
  ConsumerState<TokenCandleSection> createState() => _TokenCandleSectionState();
}

class _TokenCandleSectionState extends ConsumerState<TokenCandleSection> {
  /// A line by default; candles on request (decision 0118).
  LoopChartStyle _style = LoopChartStyle.line;

  /// MA off and VOL on by default.
  bool _averages = false;
  bool _volume = true;

  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetId,
      interval: widget.interval,
      limit: MarketCandleRequest.chartLimit,
    );
    final state = ref.watch(marketCandlesControllerProvider(request));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketCandlesControllerProvider(request).notifier).load(),
          );
        }
      });
    }
    final block = state.value?.candles;
    final candles = block is MarketCandlesAvailable ? block.items : null;
    final averages = <String>[
      if (_averages && candles != null && candles.isNotEmpty)
        for (final period in LoopMarketChart.averagePeriods)
          ?loopCandleMovingAverageLabel(candles, period),
    ];
    return Column(
      key: const ValueKey<String>('token-chart-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  averages.isEmpty ? '' : '${averages.join(' · ')} · 本机计算',
                  key: const ValueKey<String>('token-moving-averages'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureXs.copyWith(color: LoopColors.text2),
                ),
              ),
              _ChartToggle(
                key: const ValueKey<String>('token-chart-style'),
                label: _style == LoopChartStyle.line ? 'K线' : '折线',
                semantic: _style == LoopChartStyle.line ? '切换到 K 线' : '切换到折线',
                on: false,
                onTap: () => setState(
                  () => _style = _style == LoopChartStyle.line
                      ? LoopChartStyle.candles
                      : LoopChartStyle.line,
                ),
              ),
              _ChartToggle(
                key: const ValueKey<String>('token-chart-ma'),
                label: 'MA',
                semantic: '均线',
                on: _averages,
                onTap: () => setState(() => _averages = !_averages),
              ),
              _ChartToggle(
                key: const ValueKey<String>('token-chart-vol'),
                label: 'VOL',
                semantic: '成交量',
                on: _volume,
                onTap: () => setState(() => _volume = !_volume),
              ),
            ],
          ),
        ),
        if (!state.isReady || block == null)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            child: LoopChainStateBlock(
              keyPrefix: 'candles',
              phase: state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.chart,
              emptyMessage: '这个区间没有成交',
              onRetry: () => unawaited(
                ref
                    .read(marketCandlesControllerProvider(request).notifier)
                    .reload(),
              ),
            ),
          )
        else
          switch (block) {
            MarketCandlesUnavailable(reasonCode: final reasonCode) => SizedBox(
              height: widget.height,
              child: Center(
                child: LoopInlineUnavailable(
                  key: const ValueKey<String>('candles-unavailable'),
                  message: '图表暂时读不到 · ${loopReasonCodeText(reasonCode)}',
                  onRetry: _providerRateLimited(reasonCode)
                      ? null
                      : () => unawaited(
                          ref
                              .read(
                                marketCandlesControllerProvider(request)
                                    .notifier,
                              )
                              .reload(),
                        ),
                ),
              ),
            ),
            MarketCandlesAvailable(items: final items) when items.isEmpty =>
              SizedBox(
                height: widget.height,
                child: const Center(
                  child: LoopEmpty(
                    key: ValueKey<String>('candles-empty'),
                    message: '这个区间没有成交',
                    reason: '只画有成交的桶，空桶不会补 0。',
                    margin: EdgeInsets.zero,
                  ),
                ),
              ),
            MarketCandlesAvailable() => LoopMarketChart(
              key: const ValueKey<String>('token-candle-chart'),
              candles: block.items,
              interval: widget.interval,
              style: _style,
              showMovingAverages: _averages,
              showVolume: _volume,
              height: widget.height,
              semanticLabel:
                  '${block.items.length} 根${loopChartIntervalLabel(widget.interval)}'
                  '${_style == LoopChartStyle.line ? '收盘价折线' : 'K 线'}，'
                  '单位 ${block.priceUnit}'
                  '${block.items.last.isOpen ? '，最后一根尚未收盘' : ''}',
            ),
          },
        _IntervalChips(
          selected: widget.interval,
          onSelected: widget.onIntervalChanged,
          trailing: widget.trailing,
        ),
        if (block is MarketCandlesAvailable) _CandleProvenance(block: block),
      ],
    );
  }
}

/// One weak line under the chart: the series' source, pool and unit, and
/// its marker when it is stale, derived or proxied (AGENTS rule 25).
class _CandleProvenance extends StatelessWidget {
  const _CandleProvenance({required this.block});

  final MarketCandlesAvailable block;

  @override
  Widget build(BuildContext context) {
    final marker = loopFactQualityMarker(block.quality);
    final open = block.items.isNotEmpty && block.items.last.isOpen;
    return LoopProvenanceLine(
      key: const ValueKey<String>('candles-provenance'),
      prefix: <String>{
        ?marker,
        if (block.hasSourceLabel) marketCandleLabelText(block.labelKey),
        // A provider top pool is not one LOOP indexes (decision 0064): the
        // line says so, so the chart never implies a trade feed.
        if (block.pool.isProviderPool) '未登记池',
        if (open) '最后一根进行中',
        '单位 ${block.priceUnit}',
      }.join(' · '),
      sources: <String>[loopFactSourceLabel(block.source)],
      observedAt: block.fetchedAt,
      detail: <String>[
        '${marketCandleSourcePoolText(block.source, block.pool)}。',
        if (open) '最后一根尚未收盘，收盘前还会变化。',
        'MA 与 VOL 由本机按图上的收盘价与成交量计算，没有单独的数据来源。',
      ].join(''),
    );
  }
}

/// A 44pt toolbar control drawn as a small label.
class _ChartToggle extends StatelessWidget {
  const _ChartToggle({
    required this.label,
    required this.semantic,
    required this.on,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semantic;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: semantic,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: LoopTouch.minimum,
          minHeight: LoopTouch.minimum,
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: on ? LoopColors.chalk.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: LoopColors.line),
            ),
            child: Text(
              label,
              style: LoopType.figureXs.copyWith(
                color: on ? LoopColors.chalk : LoopColors.text3,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 15分 / 1时 / 4时 / 1日 / 1周, then the caller's trailing control.
class _IntervalChips extends StatelessWidget {
  const _IntervalChips({
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final LoopCandleInterval selected;
  final ValueChanged<LoopCandleInterval> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
      child: Row(
        children: <Widget>[
          for (final interval in LoopCandleInterval.values)
            Semantics(
              button: true,
              selected: interval == selected,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey<String>('token-interval-${interval.wireName}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(interval),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: LoopTouch.minimum,
                      minHeight: LoopTouch.minimum,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: interval == selected
                              ? LoopColors.chalk.withValues(alpha: 0.1)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          loopChartIntervalLabel(interval),
                          style: interval == selected
                              ? LoopType.titleSm
                              : LoopType.titleSm.copyWith(
                                  color: LoopColors.text3,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 关于 · 池与合约事实: the primary pool on one line and every contract fact,
/// risk-class first, then one source line (formerly the quote's tray).
class TokenPoolAndContractFacts extends StatelessWidget {
  const TokenPoolAndContractFacts({
    required this.pair,
    required this.security,
    super.key,
  });

  final MarketPrimaryPair? pair;
  final MarketSecurityBlock security;

  @override
  Widget build(BuildContext context) {
    final style = LoopTypography.caption(12, color: LoopColors.text2);
    final resolved = pair;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          resolved == null
              ? '主交易对：没有以该资产为 base 的交易对'
              : '主交易对：${marketDexLabel(resolved.dexId)} · 报价币 '
                    '${resolved.quoteTokenSymbol} · '
                    '${loopTruncatedAddress(resolved.pairAddress)}',
          key: const ValueKey<String>('token-facts-pair'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      const SizedBox(height: 8),
    ];
    switch (security) {
      case MarketSecurityUnavailable(reasonCode: final reasonCode):
        children.add(
          LoopInlineUnavailable(
            key: const ValueKey<String>('token-security-unavailable'),
            message: '合约事实暂时读不到 · ${loopReasonCodeText(reasonCode)}',
          ),
        );
      case MarketSecurityAvailable(facts: final facts) when facts.isEmpty:
        children.add(
          const LoopInlineUnavailable(
            key: ValueKey<String>('token-security-empty'),
            icon: 'info',
            message: '暂时读不到合约信息；少了某一项不代表安全或不安全',
          ),
        );
      case MarketSecurityAvailable(facts: final facts):
        final ordered = tokenSecurityFactsInTrayOrder(facts);
        children.add(
          Padding(
            key: const ValueKey<String>('token-security-facts'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var row = 0; row < ordered.length; row += 2)
                  Row(
                    children: <Widget>[
                      Expanded(child: TokenFactCell(fact: ordered[row])),
                      const SizedBox(width: 10),
                      Expanded(
                        child: row + 1 < ordered.length
                            ? TokenFactCell(fact: ordered[row + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
        final sources = <String>[
          for (final fact in facts) loopFactSourceLabel(fact.source),
        ];
        var oldest = facts.first.observedAt;
        for (final fact in facts) {
          if (fact.observedAt.isBefore(oldest)) oldest = fact.observedAt;
        }
        children.add(
          LoopProvenanceLine(
            key: const ValueKey<String>('token-security-provenance'),
            prefix: '合约事实 ${facts.length} 项',
            sources: sources,
            observedAt: oldest,
            detail: '这里不给评级、评分或结论。少了某一项只表示读不到，不代表安全或不安全。',
          ),
        );
    }
    return Column(
      key: const ValueKey<String>('token-pool-contract-facts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Whether [fact] is one of the contract capabilities a holder should read
/// first: a mint, a pause, a blacklist, a hidden or recoverable owner and the
/// like, when GoPlus reports it present — or a contract it could not verify.
///
/// It sorts and marks; it is never a verdict. The opposite reading is not
/// called safe, only neutral: 未检测到 is what one source did not see.
bool tokenSecurityFactIsRisk(MarketSecurityFact fact) {
  const flags = <String>{
    'proxy',
    'mintable',
    'ownershipTakeBack',
    'ownerChangeBalance',
    'hiddenOwner',
    'selfDestruct',
    'externalCall',
    'honeypot',
    'transferPausable',
    'blacklist',
    'whitelist',
    'antiWhale',
    'tradingCooldown',
    'cannotSellAll',
  };
  if (flags.contains(fact.fact)) return fact.value == 'true';
  if (fact.fact == 'openSource') return fact.value == 'false';
  return false;
}

/// The short label one fact takes in the tray's two-column grid. It keeps
/// the full sentence's claim — 检测到 / 未检测到 stays exactly that — and
/// only drops words; a key with no short form keeps its sentence.
String tokenSecurityFactShortText(MarketSecurityFact fact) {
  final isTrue = fact.value == 'true';
  final isFalse = fact.value == 'false';
  String? yesNo(String whenTrue, String whenFalse) =>
      isTrue ? whenTrue : (isFalse ? whenFalse : null);
  final short = switch (fact.fact) {
    'openSource' => yesNo('已验证开源', '未验证开源'),
    'proxy' => yesNo('代理合约', '非代理合约'),
    'mintable' => yesNo('检测到 mint', '未检测到 mint'),
    'ownershipTakeBack' => yesNo('所有权可收回', '未检测到收回所有权'),
    'ownerChangeBalance' => yesNo('所有者可改余额', '所有者不可改余额'),
    'hiddenOwner' => yesNo('检测到隐藏所有者', '未检测到隐藏所有者'),
    'selfDestruct' => yesNo('检测到自毁', '未检测到自毁'),
    'externalCall' => yesNo('检测到外部调用', '未检测到外部调用'),
    'honeypot' => yesNo('检测到蜜罐特征', '未检测到蜜罐特征'),
    'transferPausable' => yesNo('转账可暂停', '转账不可暂停'),
    'blacklist' => yesNo('检测到黑名单', '未检测到黑名单'),
    'whitelist' => yesNo('检测到白名单', '未检测到白名单'),
    'antiWhale' => yesNo('检测到持仓上限', '未检测到持仓上限'),
    'tradingCooldown' => yesNo('检测到交易冷却', '未检测到交易冷却'),
    'cannotSellAll' => yesNo('不能全部卖出', '可以全部卖出'),
    'listedOnDex' => yesNo('已在 DEX 上架', '未在 DEX 上架'),
    _ => null,
  };
  return short ?? marketSecurityFactText(fact);
}

/// The facts in the order the tray lists them: the risk-class ones first,
/// each group in the order the source gave.
List<MarketSecurityFact> tokenSecurityFactsInTrayOrder(
  List<MarketSecurityFact> facts,
) => <MarketSecurityFact>[
  ...facts.where(tokenSecurityFactIsRisk),
  ...facts.where((fact) => !tokenSecurityFactIsRisk(fact)),
];

/// One cell of the tray's fact grid: a dot and the fact's short label. The
/// full sentence is what a screen reader hears.
class TokenFactCell extends StatelessWidget {
  TokenFactCell({required this.fact})
    : risk = tokenSecurityFactIsRisk(fact),
      super(key: ValueKey<String>('token-fact-${fact.fact}'));

  final MarketSecurityFact fact;
  final bool risk;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: marketSecurityFactText(fact),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              key: ValueKey<String>('token-fact-dot-${fact.fact}'),
              decoration: BoxDecoration(
                color: risk ? LoopColors.warning : LoopColors.text3,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tokenSecurityFactShortText(fact),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.caption(
                  12,
                  color: risk ? LoopColors.chalk : LoopColors.text2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityBlock extends StatelessWidget {
  const _CommunityBlock({required this.block, required this.onOpenCommunity});

  final MarketCommunityBlock block;
  final void Function(String communityId) onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketCommunityUnavailable(reasonCode: final reasonCode):
        return LoopInlineUnavailable(
          key: const ValueKey<String>('token-community-unavailable'),
          icon: 'info',
          message: '还没有绑定的 LOOP 社区 · ${loopReasonCodeText(reasonCode)}',
        );
      case MarketCommunityBound(
        communityId: final communityId,
        name: final name,
        memberCount: final memberCount,
      ):
        return LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('token-community-entry'),
              title: '进入 LOOP 社区',
              subtitle: '$name · $memberCount 名成员',
              onTap: () => onOpenCommunity(communityId),
            ),
          ],
        );
    }
  }
}

/// The context notification entry point on the token page.
///
/// There is no standalone notification centre: price-alert notifications are
/// read here and on the `alerts` page.
class _TokenNotificationFeed extends ConsumerStatefulWidget {
  const _TokenNotificationFeed({required this.assetId});

  final String assetId;

  @override
  ConsumerState<_TokenNotificationFeed> createState() =>
      _TokenNotificationFeedState();
}

class _TokenNotificationFeedState
    extends ConsumerState<_TokenNotificationFeed> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFeedControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(notificationFeedControllerProvider.notifier).load(),
          );
        }
      });
    }
    final feed = state.value;
    if (feed == null) {
      return LoopChainStateBlock(
        keyPrefix: 'token-feed',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 1,
        emptyMessage: '还没有与这个资产相关的通知',
        onRetry: () => unawaited(
          ref.read(notificationFeedControllerProvider.notifier).reload(),
        ),
      );
    }
    final entries = feed.priceAlerts
        .where((entry) => entry.contextParams['assetId'] == widget.assetId)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('token-feed-empty'),
        message: '还没有与这个资产相关的通知',
        reason: '价格提醒触发后会出现在这里。推送还没有开放。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final entry in entries)
          LoopRecordRow(
            key: ValueKey<String>('token-feed-${entry.notificationId}'),
            title: _notificationTitle(entry),
            subtitle: _notificationDetail(entry),
            // Source and observation time on one line came out as 「来源 D…」.
            subtitleMaxLines: 2,
            trailingBadge: entry.isUnread ? const LoopBadge('未读') : null,
            onTap: entry.isUnread
                ? () => unawaited(
                    ref
                        .read(notificationFeedControllerProvider.notifier)
                        .markRead(entry.notificationId),
                  )
                : null,
          ),
      ],
    );
  }
}

String _notificationTitle(LoopNotificationEntry entry) {
  final symbol = entry.payload['symbol'];
  final threshold = entry.payload['threshold'];
  final observed = entry.payload['observedValue'];
  if (symbol == null || threshold == null || observed == null) {
    return '价格提醒已触发';
  }
  return '$symbol 触发 $threshold（观察值 $observed）';
}

String _notificationDetail(LoopNotificationEntry entry) {
  final source = loopNotificationSourceLabel(entry.source);
  final observedAt = entry.observedAt;
  return <String>[
    ?source,
    if (observedAt != null) '观察于 ${loopRelativeTime(observedAt)}',
  ].join(' · ');
}
