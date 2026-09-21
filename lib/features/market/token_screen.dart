import 'dart:async';

import 'package:decimal/decimal.dart';
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
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

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

class _TokenDetailScreenState extends ConsumerState<TokenDetailScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;

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
      title: detail == null ? 'Token' : marketAssetIdentityLabel(detail.asset),
      kicker: detail?.asset.settled?.name,
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
      // The prototype's token page has no `data-page-primary` hero: the
      // signature card *is* the primary region. LOOP pushed a second Lime
      // hero above it, which printed the price twice and cost the first
      // screen the metrics, the mining strip and the action row (audit
      // 2026-09-21 §G.2 and §D+ item 13).
      primary: _TokenPrimaryCard(
        assetId: assetId,
        detail: detail,
        miningWeight: miningWeight,
        // The card's 买入 / 卖出 read the same one gate the entry button
        // below does, and nothing else.
        tradable: detail?.capability.swappable ?? false,
        onOpenChart: () => _open(MarketAssetRoute.chart(assetId)),
        onOpenCommunity: (communityId) =>
            _open('/community/profile?id=$communityId'),
        onTrade: () => _open('/wallet/swap'),
      ),
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
          const LoopLabel('K 线'),
          _TokenCandleBlock(
            assetId: assetId,
            interval: _interval,
            onIntervalChanged: (value) => setState(() => _interval = value),
            onExpand: () => _open(MarketAssetRoute.chart(assetId)),
          ),
          const LoopLabel('行情事实'),
          LoopSurfaceCard(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopFactLine(label: '市值', fact: detail.marketCap),
                LoopFactLine(label: '完全稀释估值', fact: detail.fdv),
                LoopFactLine(label: '流动性', fact: detail.liquidityUsd),
                LoopFactLine(label: '24H 成交额', fact: detail.volume24h),
                LoopFactLine(label: '持有人数', fact: detail.holderCount),
              ],
            ),
          ),
          _PrimaryPairCard(pair: detail.primaryPair),
          const LoopLabel('社区'),
          _CommunityBlock(
            block: detail.community,
            onOpenCommunity: (communityId) =>
                _open('/community/profile?id=$communityId'),
          ),
          const LoopLabel('挖矿数据'),
          if (miningWeight == null)
            const LoopUnavailableCard(
              key: ValueKey<String>('token-mining-unavailable'),
              label: 'Mining Weight 与预估收益不可用',
              reasonCode: 'MINING_RUNTIME_DEFERRED',
            )
          else
            LoopPowerHint(
              key: const ValueKey<String>('token-mining-weight'),
              text: 'Mining Weight',
              figure: <String>[
                miningWeight.label,
                if (miningWeight.baseline) miningBaselineLabel,
              ].join(' · '),
              onTap: () => _open('/mining'),
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
          const LoopLabel('更多'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('token-holders-entry'),
                title: '持有人分布',
                // A row's second line states the value it can read, and
                // falls back to a description only when it cannot (audit
                // 2026-09-21 §D+ item 11).
                subtitle: detail.holderCount.isAvailable
                    ? '${loopFormatDecimal(detail.holderCount.value!, maxFractionDigits: 0)} 持有人 · 分布与集中度暂时读不到'
                    : '持有人总数与分布暂时读不到',
                subtitleMaxLines: 2,
                onTap: () => _open(MarketAssetRoute.holders(assetId)),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('token-trades-entry'),
                title: '交易活动',
                subtitle: '已登记池的链上成交，带确认状态',
                onTap: () => _open(MarketAssetRoute.trades(assetId)),
              ),
            ],
          ),
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

/// One Token Card metric cell from a fact. An unavailable fact renders why
/// there is no figure, never `0` and never an em dash.
///
/// Both halves are summaries, because the cell is a third of a card wide: the
/// figure is compact (`$5.4B`) and the missing-value copy is a phrase rather
/// than the full sentence. The exact number, the source, the observation time
/// and the server's own reason all render in full in the fact list further
/// down the same page, which is unchanged.
LoopTokenMetric _cardMetric(String label, LoopFact fact, {bool usd = true}) =>
    LoopTokenMetric(
      label,
      fact.isAvailable
          ? loopFormatCompactFigure(fact.value!, usd: usd)
          : loopReasonCodeSummaryText(fact.reasonCode),
    );

/// The prototype's `.tcard.tcard-signature.tcard-token-hero`, in the page's
/// `[data-page-primary]` slot.
///
/// Quote, 1H line, three metrics, the Mining Weight strip and the four-segment
/// action row — 买入 / 卖出 / 图表 / 社区 — all in one card, exactly as the
/// prototype opens this page. Every figure comes from the same
/// `MarketAssetDetail` the fact list further down reads, and an unavailable
/// one renders its `reasonCode` instead of a number.
class _TokenPrimaryCard extends StatelessWidget {
  const _TokenPrimaryCard({
    required this.assetId,
    required this.detail,
    required this.miningWeight,
    required this.tradable,
    required this.onOpenChart,
    required this.onOpenCommunity,
    required this.onTrade,
  });

  final String assetId;
  final MarketAssetDetail? detail;
  final MarketMiningWeight? miningWeight;

  /// Whether 买入 / 卖出 may be pressed at all. While it is false the two
  /// segments stay on the card and stay disabled: the prototype's first
  /// screen is a four-segment row, and dropping two of them moved the
  /// question 「能不能买」 off the page entirely (audit 2026-09-21 §G.2).
  final bool tradable;
  final VoidCallback onOpenChart;
  final void Function(String communityId) onOpenCommunity;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final resolved = detail;
    if (resolved == null) {
      // 识别中: the prototype's own loading card, not a second title bar.
      return LoopTokenCard(
        key: const ValueKey<String>('token-card-loading'),
        state: LoopTokenCardState.loading,
        model: LoopTokenCardModel(
          symbol: loopTruncatedAssetId(assetId),
          identifier: loopTruncatedAssetId(assetId),
        ),
      );
    }
    if (resolved.capability.blocksEntirePage) {
      // A blocked asset shows no fact at all, not even a quote.
      return LoopTokenCard(
        key: const ValueKey<String>('token-card-blocked'),
        state: LoopTokenCardState.partial,
        model: LoopTokenCardModel(
          symbol: marketAssetIdentityLabel(resolved.asset),
          identifier: loopTruncatedAssetId(assetId),
          priceReason: loopReasonCodeText(
            resolved.capability.reasonCode ?? 'ASSET_BLOCKED',
          ),
        ),
      );
    }
    final community = resolved.community;
    final weight = miningWeight;
    return LoopTokenCard(
      key: const ValueKey<String>('token-card'),
      state: LoopTokenCardState.normal,
      model: LoopTokenCardModel(
        symbol: marketAssetIdentityLabel(resolved.asset),
        identifier: loopTruncatedAssetId(assetId),
        price: resolved.price.isAvailable
            ? loopFormatUsd(resolved.price.value!)
            : null,
        priceReason: resolved.price.isAvailable
            ? null
            : loopReasonCodeText(resolved.price.reasonCode),
        change: resolved.priceChange24h.isAvailable
            ? loopFormatPercent(resolved.priceChange24h.value!)
            : null,
        changeUp: resolved.priceChange24h.isAvailable
            ? resolved.priceChange24h.value! >= Decimal.zero
            : null,
        metrics: <LoopTokenMetric>[
          _cardMetric('市值', resolved.marketCap),
          _cardMetric('流动性', resolved.liquidityUsd),
          _cardMetric('持有人', resolved.holderCount, usd: false),
        ],
        // `.tcard-community`: the prototype's Lime strip is the mining line,
        // not a provenance note. It falls back to the quote's provenance only
        // when no weight was published for this asset.
        communityIcon: weight == null ? 'info' : 'mine',
        communityLine: weight != null
            ? <String>[
                'Mining Weight ${weight.label}',
                if (weight.baseline) miningBaselineLabel,
                if (community case MarketCommunityBound(
                  memberCount: final memberCount,
                ))
                  '$memberCount 成员',
              ].join(' · ')
            : resolved.price.isAvailable
            ? '报价 ${loopFactProvenance(resolved.price)}'
            : '这张卡片的每个数字都取自下方同一份数据，读不到的一项会说明原因，不会显示 0。',
        footnotes: <String>[if (!tradable) '买入与卖出当前不可用，原因见本页底部。'],
        chartRangeLabel: '1H · 最近 $loopSparklineWindow 根收盘价',
        chart: TokenCardSparkline(
          assetId: assetId,
          keyPrefix: 'token-card-chart',
          unavailableText: '1H 走势不可用，原因见下方 K 线。',
        ),
      ),
      actions: <LoopTokenCardAction>[
        LoopTokenCardAction('买入', buy: true, onTap: tradable ? onTrade : null),
        LoopTokenCardAction('卖出', onTap: tradable ? onTrade : null),
        LoopTokenCardAction('图表', onTap: onOpenChart),
        if (community case MarketCommunityBound(communityId: final communityId))
          LoopTokenCardAction('社区', onTap: () => onOpenCommunity(communityId)),
      ],
    );
  }
}

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSurfaceCard(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
                  ),
                },
            ],
          ),
        ),
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
  });

  final MarketCandlesAvailable block;
  final double height;
  final List<int> movingAveragePeriods;
  final bool showVolume;

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
            Text('O ${loopFormatDecimal(last.open)}', style: LoopMono.body),
            Text('H ${loopFormatDecimal(last.high)}', style: LoopMono.body),
            Text('L ${loopFormatDecimal(last.low)}', style: LoopMono.body),
            Text(
              'C ${loopFormatDecimal(last.close)}',
              style: LoopMono.body.copyWith(
                color: last.isUp ? LoopColors.lime : LoopColors.chalk,
              ),
            ),
          ],
        ),
        // `.kline-ma`: the averages the chart draws, read out above it. They
        // are computed here from the closes already on screen, so the line
        // says so rather than borrowing the series' source.
        if (movingAveragePeriods.isNotEmpty) ...<Widget>[
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
                  '来源 ${loopFactSourceLabel(block.source)}',
                  '观察于 ${loopRelativeTime(block.fetchedAt)}',
                  '池 ${loopTruncatedAddress(block.pool.address)}',
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
