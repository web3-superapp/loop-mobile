import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_tray_disclosure.dart';

/// `token` · one registry asset's facts.
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

/// The four tabs the approved design puts under the chart, in its order.
enum TokenSectionTab {
  community('社区'),
  holders('持有人'),
  trades('成交'),
  about('简介');

  const TokenSectionTab(this.label);

  final String label;
}

class _TokenDetailScreenState extends ConsumerState<TokenDetailScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;
  TokenSectionTab _tab = TokenSectionTab.community;

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
        MarketCandleRequest(assetId: assetId, interval: _interval),
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
    // funds row and the swap page both read. Without it this page fell back to
    // a sentence of its own and the same closed switch got a third name.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    // Mining, where 行情 touches it: the prototype's Token Card carries a
    // `Mining Weight` strip and LOOP printed 「不可用」 over the whole module
    // (audit 2026-09-21 §G.2). This is the rules answer the Mining module
    // already reads; a weight it does not list is left off.
    final miningRules = watchMarketMiningRules(ref);
    final miningWeight = marketMiningWeightFor(miningRules, assetId);
    final swapBlockedReason = swapGate.isAvailable
        ? (detail?.capability.reasonCode ?? 'SWAP_MODULE_NOT_DELIVERED')
        : (swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE');

    return LoopDashboardPage(
      key: ValueKey<String>('token-screen-$assetId'),
      onRefresh: ref
          .read(marketAssetControllerProvider(assetId).notifier)
          .reload,
      archetype: LoopPageArchetype.record,
      // The approved design pins the two actions to the foot of the page:
      // on an exchange they are reachable from wherever the reader is, and
      // this page is long. Same single gate, same two labels, new place
      // (decision 0086; 0084's first unlanded item). The bar is withheld
      // while the page has no facts at all — there is nothing to trade on a
      // page that is still a skeleton or a whole-page refusal.
      bottomBar: detail == null || detail.capability.blocksEntirePage
          ? null
          : MarketTradeBar(
              key: const ValueKey<String>('token-trade-bar'),
              tradable: detail.capability.swappable,
              onTrade: () => _open('/wallet/swap'),
            ),
      // `ETH / USD` over `Ethereum · BSC · 0x2170…33f8`: the approved design's
      // top bar states the pair and, under it, what the pair is written
      // against. The quote currency is part of the reading — the price on the
      // line below is in it.
      title: detail == null
          ? loopTruncatedAssetId(assetId)
          : '${marketAssetIdentityLabel(detail.asset)} / USD',
      subtitle: <String>[
        ?detail?.asset.settled?.name,
        loopTruncatedAssetId(assetId),
      ].join(' · '),
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
        // and toggles it. It never navigates, because the editor can only
        // reorder and remove what is already there.
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
      ],
      // The approved design opens on the quote itself: no card, no hero. A
      // signature card around the price spent a third of the first screen on
      // its own border and pushed the chart off it.
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
          MarketQuoteHeader(
            key: const ValueKey<String>('token-quote'),
            price: detail.price,
            change: detail.priceChange24h,
          ),
          // The design's own four: the window first, then the two size
          // figures. 持有人 and 流动性 move down to the 社区 tab's strip —
          // neither is read while the reader is looking at the price.
          //
          // The pool and contract facts ride in a tray under the four cells
          // (decision 0092): one line closed, every fact with its source and
          // time when opened. The same facts keep their own blocks under 成交
          // and 简介; the tray is where they are read without leaving the
          // quote.
          LoopTrayDisclosure(
            key: const ValueKey<String>('token-facts-tray'),
            // The four cells sit on a panel exactly as wide as the tray, so
            // the pair reads as a card with its tray rather than a figure
            // row with a pill floating under it (decision 0096).
            trayInset: LoopSpacing.page,
            semanticLabel: '池与合约事实',
            card: TokenQuotePanel(
              child: MarketQuoteCells(
                key: const ValueKey<String>('token-quote-cells'),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                cells: <MarketStatCell>[
                  marketRangeCell('24h 高', detail.range24h, high: true),
                  marketRangeCell('24h 低', detail.range24h, high: false),
                  MarketStatCell.fact(
                    '24h 成交额',
                    detail.volume24h,
                    formatter: loopFormatCompactFigure,
                  ),
                  MarketStatCell.fact(
                    '市值',
                    detail.marketCap,
                    formatter: loopFormatCompactFigure,
                  ),
                ],
              ),
            ),
            summary: Text(
              tokenFactsTraySummary(detail.primaryPair, detail.security),
              key: const ValueKey<String>('token-facts-tray-summary'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.caption(12, color: LoopColors.text2),
            ),
            detail: TokenFactsTrayDetail(
              pair: detail.primaryPair,
              security: detail.security,
              onOpenAbout: () => setState(() => _tab = TokenSectionTab.about),
            ),
            margin: const EdgeInsets.only(bottom: 6),
          ),
          // Nothing could describe this contract for this request. The page
          // still stands — every figure below states its own reason — but it
          // opens by naming the address it asked about instead of a heading
          // that would read as an identity LOOP has.
          if (detail.asset case final MarketAssetIdentityUnavailable identity)
            LoopUnavailableCard(
              key: const ValueKey<String>('token-asset-unavailable'),
              label: marketAssetUnavailableHeading(identity),
              reasonCode: identity.reasonCode,
              action: LoopButton(
                key: const ValueKey<String>('token-asset-unavailable-retry'),
                label: '重试',
                // The server said the asks are coming too fast. Asking again
                // now spends the next one for the same sentence, so the
                // button states the wait rather than inviting it.
                onPressed: _providerRateLimited(identity.reasonCode)
                    ? null
                    : () => unawaited(
                        ref
                            .read(
                              marketAssetControllerProvider(assetId).notifier,
                            )
                            .reload(),
                      ),
              ),
            )
          else if (detail.capability.suppressesLiveFigures)
            LoopUnavailableCard(
              key: const ValueKey<String>('token-live-suppressed'),
              label: '链上读取暂时不可用',
              reasonCode:
                  detail.capability.reasonCode ??
                  'BSC_CHAIN_RUNTIME_UNAVAILABLE',
            ),
          // 周期 + MA，一行，紧贴 K 线上方 —— the design's own control row.
          // The chart carries the volume bars in the same panel, so the whole
          // reading is on the first screen.
          _TokenCandleBlock(
            assetId: assetId,
            interval: _interval,
            onIntervalChanged: (value) => setState(() => _interval = value),
            onExpand: () => _open(MarketAssetRoute.chart(assetId)),
          ),
          // 社区 / 持有人 / 成交 / 简介 — the design's lower half. The page
          // used to run every block down one column with a 「更多」 group of
          // links at the foot; a reader looking for the holders had to scroll
          // past the contract facts to find a row that opened another page.
          // The tab strip keeps every block one tap away and the page one
          // screen long. Switching a tab changes what is listed and nothing
          // else: no read is re-issued and no figure moves.
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
          const SizedBox(height: 12),
          ...switch (_tab) {
            // 社区 lists the bound community as a row, as the design does,
            // and follows it with the three figures the quote strip no longer
            // has room for.
            TokenSectionTab.community => <Widget>[
              _CommunityBlock(
                block: detail.community,
                onOpenCommunity: (communityId) =>
                    _open('/community/profile?id=$communityId'),
              ),
              const SizedBox(height: 10),
              MarketQuoteCells(
                key: const ValueKey<String>('token-community-cells'),
                cells: <MarketStatCell>[
                  MarketStatCell.fact(
                    '持有人',
                    detail.holderCount,
                    formatter: (value) =>
                        loopFormatCompactFigure(value, usd: false),
                  ),
                  MarketStatCell.fact(
                    '流动性',
                    detail.liquidityUsd,
                    formatter: loopFormatCompactFigure,
                  ),
                ],
              ),
              // The one place this page states the weight, and the one of the
              // two that opens 挖矿. The development label is not printed
              // beside the figure: which rules version published it is a
              // property of the release, and 关于 describes the release.
              if (miningWeight == null)
                const LoopUnavailableCard(
                  key: ValueKey<String>('token-mining-unavailable'),
                  label: '挖矿权重与预估收益不可用',
                  reasonCode: 'MINING_RUNTIME_DEFERRED',
                )
              else
                LoopPowerHint(
                  key: const ValueKey<String>('token-mining-weight'),
                  text: '挖矿权重',
                  figure: miningWeight.label,
                  onTap: () => _open('/mining'),
                ),
            ],
            TokenSectionTab.holders => <Widget>[
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  LoopRecordRow(
                    key: const ValueKey<String>('token-holders-entry'),
                    title: '持有人分布',
                    // A row's second line states the value it can read, and
                    // falls back to a description only when it cannot.
                    subtitle: detail.holderCount.isAvailable
                        ? '${loopFormatDecimal(detail.holderCount.value!, maxFractionDigits: 0)} 持有人 · 分布与集中度暂时读不到'
                        : '持有人总数与分布暂时读不到',
                    subtitleMaxLines: 2,
                    onTap: () => _open(MarketAssetRoute.holders(assetId)),
                  ),
                ],
              ),
              MarketFactProvenance(
                key: const ValueKey<String>('token-holders-provenance'),
                prefix: '持有人',
                facts: <LoopFact>[detail.holderCount],
              ),
            ],
            TokenSectionTab.trades => <Widget>[
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  LoopRecordRow(
                    key: const ValueKey<String>('token-trades-entry'),
                    title: '交易活动',
                    subtitle: '已登记池的链上成交，带确认状态',
                    onTap: () => _open(MarketAssetRoute.trades(assetId)),
                  ),
                ],
              ),
              _PrimaryPairCard(pair: detail.primaryPair),
            ],
            TokenSectionTab.about => <Widget>[
              // The cells over the chart and under 社区 carry every figure the
              // page holds except this one, which has no cell anywhere. What
              // is left for 简介 is that figure, where the set came from, what
              // the contract says, and the notifications this asset raised.
              LoopSurfaceCard(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    LoopFactLine(label: '完全稀释估值', fact: detail.fdv),
                  ],
                ),
              ),
              MarketFactProvenance(
                key: const ValueKey<String>('token-facts-provenance'),
                prefix: '上方四格',
                facts: <LoopFact>[
                  detail.volume24h,
                  detail.marketCap,
                  detail.liquidityUsd,
                  detail.holderCount,
                ],
              ),
              const LoopLabel('合约事实'),
              _SecurityBlock(block: detail.security),
              const LoopNotice(
                key: ValueKey<String>('token-facts-notice'),
                title: '只给标注出处和时间的数据',
                body: '这里不给评级、评分或结论。少了某一项只表示读不到，不代表安全或不安全。',
              ),
              const LoopLabel('通知'),
              _TokenNotificationFeed(assetId: assetId),
            ],
          },
          // The only gate for a Swap entry point. The backend pins it to
          // false until D15, so the card's 买入 / 卖出 segments above are
          // drawn disabled and this card holds the one full sentence that
          // says why.
          if (detail.capability.swappable)
            LoopButton(
              key: const ValueKey<String>('token-swap-entry'),
              label: '兑换',
              primary: true,
              block: true,
              onPressed: () => _open('/wallet/swap'),
            )
          else
            LoopUnavailableCard(
              key: const ValueKey<String>('token-swap-unavailable'),
              label: '买入、卖出与兑换当前不可用',
              // A closed gate is the whole app's answer and outranks this
              // asset's own: while it is shut, every surface says the one
              // sentence it publishes. Only once it opens can this asset have
              // a reason of its own.
              reasonCode: swapBlockedReason,
            ),
        ],
      ],
    );
  }
}

/// Whether the server's reason is the provider's own quota being spent.
///
/// A retry against it buys the same sentence and one fewer request, so the
/// surfaces that offer a retry hold it shut while this is the reason.
bool _providerRateLimited(String? reasonCode) =>
    reasonCode == 'MARKET_PROVIDER_RATE_LIMITED';

class _TokenCandleBlock extends ConsumerWidget {
  const _TokenCandleBlock({
    required this.assetId,
    required this.interval,
    required this.onIntervalChanged,
    required this.onExpand,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final ValueChanged<LoopCandleInterval> onIntervalChanged;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TokenCandleSection(
      assetId: assetId,
      interval: interval,
      onIntervalChanged: onIntervalChanged,
      // The design's own shape: the periods and the two averages on one line
      // directly over the panel, the panel itself carrying the volume bars.
      compactControls: true,
      height: 236,
      movingAveragePeriods: const <int>[7, 25],
      trailing: LoopIconButton(
        key: const ValueKey<String>('token-chart-expand'),
        icon: 'expand',
        label: '打开全屏 K 线',
        onPressed: onExpand,
      ),
    );
  }
}

/// The candle block shared by `token` and `chart-full`.
class TokenCandleSection extends ConsumerStatefulWidget {
  const TokenCandleSection({
    required this.assetId,
    required this.interval,
    required this.onIntervalChanged,
    super.key,
    this.trailing,
    this.height = 210,
    this.movingAveragePeriods = const <int>[],
    this.showVolume = true,
    this.footer,
    this.compactControls = false,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final ValueChanged<LoopCandleInterval> onIntervalChanged;
  final Widget? trailing;
  final double height;

  /// `.kline-ma`: the close-price averages drawn over the bodies and read out
  /// above them. Empty on the inline card, which has no indicator row.
  final List<int> movingAveragePeriods;

  /// `.kline-volume`: the bar row under the price panel.
  final bool showVolume;

  /// `.kline-tools`: the control row the owning page puts under the interval
  /// segments, inside the same terminal card.
  final Widget? footer;

  /// The approved design's layout: the five periods and the moving-average
  /// readout share **one** line directly above the panel, and the panel has no
  /// card of its own. 代币 uses it. `chart-full` keeps the segmented bar under
  /// the card, where it has a whole screen to spend.
  final bool compactControls;

  @override
  ConsumerState<TokenCandleSection> createState() => _TokenCandleSectionState();
}

class _TokenCandleSectionState extends ConsumerState<TokenCandleSection> {
  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetId,
      interval: widget.interval,
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
    final series = state.value;
    final block = series?.candles;

    final body = <Widget>[
      if (widget.compactControls)
        // 周期 + MA 读数，一行，紧贴 K 线上方 (the approved design). The
        // averages are computed from the closes already on screen, so they
        // are read out beside the control that chose them rather than
        // borrowing the series' own provenance line.
        _CompactChartControls(
          selected: widget.interval,
          onSelected: widget.onIntervalChanged,
          periods: widget.movingAveragePeriods,
          candles: block is MarketCandlesAvailable ? block.items : null,
          trailing: widget.trailing,
        )
      else
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                // The provider's unit string is printed verbatim — it
                // names the two assets and LOOP does not translate a
                // fact — but it is not a heading, and standing alone it
                // left this card labelled only 「USD per WBNB」.
                block is MarketCandlesAvailable
                    ? 'K 线 · 单位 ${block.priceUnit}'
                    : 'K 线',
                style: LoopMono.label,
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      const SizedBox(height: 8),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSurfaceCard(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...body,
              if (!state.isReady || block == null)
                LoopChainStateBlock(
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
                )
              else
                switch (block) {
                  MarketCandlesUnavailable(reasonCode: final reasonCode) =>
                    LoopUnavailableCard(
                      key: const ValueKey<String>('candles-unavailable'),
                      label: 'K 线不可用',
                      reasonCode: reasonCode,
                      margin: EdgeInsets.zero,
                    ),
                  MarketCandlesAvailable() => _CandleBody(
                    block: block,
                    height: widget.height,
                    movingAveragePeriods: widget.movingAveragePeriods,
                    showVolume: widget.showVolume,
                    // The compact layout already reads the averages out on the
                    // control line; repeating them under the OHLC row would
                    // print MA7 twice on one screen.
                    readOutAverages: !widget.compactControls,
                  ),
                },
            ],
          ),
        ),
        if (!widget.compactControls)
          _IntervalBar(
            selected: widget.interval,
            onSelected: widget.onIntervalChanged,
          ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}

class _CandleBody extends StatelessWidget {
  const _CandleBody({
    required this.block,
    required this.height,
    this.movingAveragePeriods = const <int>[],
    this.showVolume = true,
    this.readOutAverages = true,
  });

  final MarketCandlesAvailable block;
  final double height;
  final List<int> movingAveragePeriods;
  final bool showVolume;

  /// Whether the averages get their own line under the OHLC row.
  final bool readOutAverages;

  @override
  Widget build(BuildContext context) {
    if (block.items.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('candles-empty'),
        message: '这个区间没有成交',
        reason: '只画有成交的桶，空桶不会补 0。',
        margin: EdgeInsets.zero,
      );
    }
    final last = block.items.last;
    final marker = loopFactQualityMarker(block.quality);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            Text('O ${loopFormatCandlePrice(last.open)}', style: LoopMono.body),
            Text('H ${loopFormatCandlePrice(last.high)}', style: LoopMono.body),
            Text('L ${loopFormatCandlePrice(last.low)}', style: LoopMono.body),
            Text(
              'C ${loopFormatCandlePrice(last.close)}',
              style: LoopMono.body.copyWith(
                // A falling close used to be Chalk — the colour of O, H and L
                // beside it — so the one figure on the line that carries a
                // direction was the one figure that did not show it
                // (decision 0086).
                color: LoopPriceMove.between(
                  open: last.open,
                  close: last.close,
                ).color,
              ),
            ),
          ],
        ),
        // `.kline-ma`: the averages the chart draws, read out above it. They
        // are computed here from the closes already on screen, so the line
        // says so rather than borrowing the series' source.
        if (readOutAverages && movingAveragePeriods.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Wrap(
            key: const ValueKey<String>('candles-moving-averages'),
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              for (final period in movingAveragePeriods)
                if (loopCandleMovingAverageLabel(block.items, period)
                    case final label?)
                  Text(label, style: LoopMono.body),
              Text(
                'VOL ${loopFormatDecimal(last.volume, maxFractionDigits: 2)}',
                style: LoopMono.body,
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        LoopCandleChart(
          key: const ValueKey<String>('token-candle-chart'),
          candles: block.items,
          height: height,
          movingAveragePeriods: movingAveragePeriods,
          showVolume: showVolume,
          semanticLabel:
              '${block.items.length} 根 K 线，单位 ${block.priceUnit}'
              '${last.isOpen ? '，最后一根尚未收盘' : ''}',
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            if (marker != null) ...<Widget>[
              LoopBadge(
                marker,
                key: const ValueKey<String>('candles-quality-marker'),
                // Only a stale series is a warning; `derived` and `proxied`
                // are honest descriptions of what is being charted.
                kind: block.quality == LoopFactQuality.stale
                    ? LoopBadgeKind.down
                    : LoopBadgeKind.mute,
              ),
              const SizedBox(width: 8),
            ],
            if (last.isOpen) ...<Widget>[
              const LoopBadge(
                '最后一根进行中',
                key: ValueKey<String>('candles-open-marker'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                <String>[
                  // A proxied series may also be an on-chain aggregate, so
                  // the label is shown whenever the server sends one.
                  if (block.hasSourceLabel)
                    marketCandleLabelText(block.labelKey),
                  // The compact layout has no card heading to carry the
                  // provider's unit string, and 「2,770.44」 is only a reading
                  // once the reader knows what it is priced in. It prints
                  // verbatim, as it does in the heading: LOOP does not
                  // translate a fact.
                  if (!readOutAverages) '单位 ${block.priceUnit}',
                  // Source and pool are one clause: a provider top pool is
                  // charted but not indexed by LOOP, and saying 「来源
                  // GeckoTerminal」 apart from 「未登记池」 would let the chart
                  // imply a trade feed that this asset does not have.
                  marketCandleSourcePoolText(block.source, block.pool),
                  '观察于 ${loopRelativeTime(block.fetchedAt)}',
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 周期 + MA 读数，一行 (approved design). Five periods on the left as compact
/// chips, the two averages read out on the right.
///
/// It replaces a 44pt segmented bar **under** the chart card with a 28pt line
/// **over** it, which is what puts the whole reading — price, window, periods,
/// averages, candles and volume — on the first screen.
class _CompactChartControls extends StatelessWidget {
  const _CompactChartControls({
    required this.selected,
    required this.onSelected,
    required this.periods,
    required this.candles,
    this.trailing,
  });

  final LoopCandleInterval selected;
  final ValueChanged<LoopCandleInterval> onSelected;
  final List<int> periods;

  /// `null` while the series is not readable: the periods stay operable and
  /// the readout says nothing rather than printing a stale average.
  final List<LoopCandle>? candles;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final series = candles;
    final labels = <String>[
      if (series != null)
        for (final period in periods)
          ?loopCandleMovingAverageLabel(series, period),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final interval in LoopCandleInterval.values)
              Semantics(
                button: true,
                selected: interval == selected,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey<String>(
                      'token-interval-${interval.wireName}',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onSelected(interval),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: interval == selected
                            ? LoopColors.chalk.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        interval.label,
                        // The chosen period takes the ladder's own small title —
                        // Chalk by default — and the rest take it at the grey the
                        // tab strip uses, so the row has one weight and one size.
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
            const Spacer(),
            ?trailing,
          ],
        ),
        // The averages get the line under the periods, not the room left
        // beside them: five tabs and the expand glyph leave a 360dp phone
        // about 60dp, and 「MA7 780.2386 · MA25 786.5496」 was reaching the
        // reader as 「MA7 7…」.
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            labels.join(' · '),
            key: const ValueKey<String>('token-moving-averages'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopType.figureXs,
          ),
        ],
      ],
    );
  }
}

class _IntervalBar extends StatelessWidget {
  const _IntervalBar({required this.selected, required this.onSelected});

  final LoopCandleInterval selected;
  final ValueChanged<LoopCandleInterval> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: <Widget>[
          for (final interval in LoopCandleInterval.values) ...<Widget>[
            LoopSeg(
              key: ValueKey<String>('candle-interval-${interval.wireName}'),
              label: interval.label,
              selected: interval == selected,
              onSelected: () => onSelected(interval),
            ),
            if (interval != LoopCandleInterval.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// The one line the token page's fact tray shows closed.
///
/// It names what the tray holds and how much of it was read, never a verdict:
/// a count of contract facts is not a statement that any of them is good.
String tokenFactsTraySummary(
  MarketPrimaryPair? pair,
  MarketSecurityBlock security,
) {
  final pool = pair == null
      ? '没有主交易对'
      : '主交易对 ${pair.dexId} · 报价币 ${pair.quoteTokenSymbol}';
  final facts = switch (security) {
    MarketSecurityAvailable(facts: final facts) when facts.isEmpty =>
      '合约事实暂时读不到',
    MarketSecurityAvailable(facts: final facts) => '合约事实 ${facts.length} 项',
    MarketSecurityUnavailable() => '合约事实不可用',
  };
  return '$pool · $facts';
}

/// The quote cells' own ground: an opaque panel one step off the page, as
/// wide as the fact tray tucked under it.
///
/// It is opaque on purpose: the tray is painted first and runs up under the
/// panel's lower edge, and a translucent panel would show it through.
class TokenQuotePanel extends StatelessWidget {
  const TokenQuotePanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: DecoratedBox(
        key: const ValueKey<String>('token-quote-panel'),
        decoration: BoxDecoration(
          color: Color.alphaBlend(LoopGround.tintOf(context), LoopColors.ink),
          borderRadius: LoopRadius.card,
          border: Border.all(color: LoopGround.hairlineOf(context)),
        ),
        child: child,
      ),
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

/// The one provenance line under the tray's grid: every source the facts
/// name, and the oldest observation among them — the grid is only as fresh
/// as its stalest cell.
String tokenSecurityProvenanceLine(List<MarketSecurityFact> facts) {
  final sources = <String>{
    for (final fact in facts) loopFactSourceLabel(fact.source),
  };
  var oldest = facts.first.observedAt;
  for (final fact in facts) {
    if (fact.observedAt.isBefore(oldest)) oldest = fact.observedAt;
  }
  return '来源 ${sources.join('、')} · 观察于 ${loopRelativeTime(oldest)}';
}

/// The open fact tray (decision 0096): the pool on one line, then at most
/// [maxCells] contract facts as a compact two-column grid — risk-class ones
/// first, each behind a Warning dot, the rest behind a neutral one — then,
/// when there are more, one control that opens 简介 where every fact is
/// listed, and a single provenance line at the foot.
class TokenFactsTrayDetail extends StatelessWidget {
  const TokenFactsTrayDetail({
    required this.pair,
    required this.security,
    required this.onOpenAbout,
    super.key,
  });

  static const int maxCells = 8;

  final MarketPrimaryPair? pair;
  final MarketSecurityBlock security;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final style = LoopTypography.caption(12, color: LoopColors.text2);
    final resolved = pair;
    final pairLine = resolved == null
        ? '主交易对：没有以该资产为 base 的交易对'
        : '主交易对：${resolved.dexId} · 报价币 ${resolved.quoteTokenSymbol} · '
              '${loopTruncatedAddress(resolved.pairAddress)}';
    final children = <Widget>[
      Text(
        pairLine,
        key: const ValueKey<String>('token-facts-tray-pair'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
      const SizedBox(height: 8),
    ];
    switch (security) {
      case MarketSecurityUnavailable(reasonCode: final reasonCode):
        children.add(
          Text('合约事实不可用：${loopReasonCodeText(reasonCode)}', style: style),
        );
      case MarketSecurityAvailable(facts: final facts) when facts.isEmpty:
        children.add(Text('暂时读不到合约信息。少了某一项只表示读不到，不代表安全或不安全。', style: style));
      case MarketSecurityAvailable(facts: final facts):
        final ordered = tokenSecurityFactsInTrayOrder(facts);
        final shown = ordered.take(maxCells).toList(growable: false);
        final hidden = ordered.length - shown.length;
        children.add(
          Column(
            key: const ValueKey<String>('token-facts-tray-grid'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var row = 0; row < shown.length; row += 2)
                Row(
                  children: <Widget>[
                    Expanded(child: TokenFactCell(fact: shown[row])),
                    const SizedBox(width: 10),
                    Expanded(
                      child: row + 1 < shown.length
                          ? TokenFactCell(fact: shown[row + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
        );
        if (hidden > 0) {
          children.add(
            Semantics(
              button: true,
              label: '更多 $hidden 项，在简介查看',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey<String>('token-facts-tray-more'),
                onTap: onOpenAbout,
                borderRadius: LoopRadius.control,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '更多 $hidden 项',
                        style: LoopTypography.caption(
                          12,
                          color: LoopColors.chalk,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const LoopIcon(
                        'chevron',
                        size: 12,
                        color: LoopColors.text2,
                      ),
                      const SizedBox(width: 6),
                      Text('简介', style: style),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          children.add(const SizedBox(height: 6));
        }
        children.add(
          Text(
            tokenSecurityProvenanceLine(facts),
            key: const ValueKey<String>('token-facts-tray-source'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.caption(11, color: LoopColors.text3),
          ),
        );
    }
    return Column(
      key: const ValueKey<String>('token-facts-tray-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

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

class _PrimaryPairCard extends StatelessWidget {
  const _PrimaryPairCard({required this.pair});

  final MarketPrimaryPair? pair;

  @override
  Widget build(BuildContext context) {
    final resolved = pair;
    if (resolved == null) {
      return const LoopUnavailableCard(
        key: ValueKey<String>('token-primary-pair-unavailable'),
        label: '没有以该资产为 base 的交易对',
        reasonCode: 'MARKET_PAIR_NOT_FOUND',
      );
    }
    return LoopSurfaceCard(
      key: const ValueKey<String>('token-primary-pair'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('主交易对', style: LoopMono.label),
          const SizedBox(height: 6),
          Text(
            '${resolved.dexId} · 报价币 ${resolved.quoteTokenSymbol}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            loopTruncatedAddress(resolved.pairAddress),
            style: LoopMono.stamp,
          ),
        ],
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
        return LoopUnavailableCard(
          key: const ValueKey<String>('token-community-unavailable'),
          label: '还没有绑定的 LOOP 社区',
          reasonCode: reasonCode,
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

class _SecurityBlock extends StatelessWidget {
  const _SecurityBlock({required this.block});

  final MarketSecurityBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketSecurityUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('token-security-unavailable'),
          label: '合约事实不可用',
          reasonCode: reasonCode,
        );
      case MarketSecurityAvailable(facts: final facts):
        if (facts.isEmpty) {
          return const LoopEmpty(
            key: ValueKey<String>('token-security-empty'),
            message: '暂时读不到合约信息',
            reason: '少了某一项只表示读不到，不代表安全或不安全。',
          );
        }
        return LoopSurfaceCard(
          key: const ValueKey<String>('token-security-facts'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final fact in facts) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${marketSecurityFactText(fact)} —— '
                    '来源 ${loopFactSourceLabel(fact.source)}，'
                    '观察于 ${loopRelativeTime(fact.observedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
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
