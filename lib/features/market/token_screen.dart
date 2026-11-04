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
import 'package:loop_mobile/features/market/loop_chart_toolbar.dart';
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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

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
  holders(),
  activity(),
  about();

  const TokenSectionTab();

  String get label => switch (this) {
    TokenSectionTab.holders => LoopL10n.current.market_tokenHolders,

    TokenSectionTab.activity => LoopL10n.current.common_feed,

    TokenSectionTab.about => LoopL10n.current.common_aboutSection,
  };
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
      if (asset?.address case final address?)
        LoopL10n.current.market_tokenShare(address)
      else
        assetId,
      LoopL10n.current.market_tokenShare2,
    ].join('\n');
    final shown = await ref.read(loopTextShareProvider)(text);
    if (!mounted || shown) return;
    LoopToast.show(
      context,
      message: LoopL10n.current.market_tokenMessage,
      kind: LoopToastKind.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return LoopFocusPage(
        key: const ValueKey<String>('token-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.market_tokenTokenInvalidRouteTitle,
        onBack: widget.onBack,
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('token-invalid-identity'),
            illustration: LoopIllustration.chartEmpty,
            title:
                context.l10n.market_secondaryScreensInvalidAssetIdentityTitle,
            message: context.l10n.market_tokenTokenInvalidIdentityMessage,
            compact: true,
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
          label: context.l10n.common_priceAlerts,
          onPressed: () => _open(MarketAssetRoute.alerts(assetId)),
        ),
        // The star is the whole "add to watchlist" path: it states membership
        // and toggles it. It never navigates.
        LoopIconButton(
          key: const ValueKey<String>('token-watchlist-action'),
          icon: 'star',
          label: watchlistBlocked
              ? context.l10n.market_secondaryScreensLabel2
              : membership.actionLabel,
          color: membership.isWatched ? LoopColors.yellow : null,
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
          label: context.l10n.common_share,
          onPressed: () => unawaited(_share(assetId, detail)),
        ),
      ],
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('token-capability-block'),
              title: context.l10n.market_screenMarketCapabilityBlockTitle,
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
            emptyMessage: context.l10n.market_tokenEmptyMessage,
            onRetry: () => unawaited(
              ref
                  .read(marketAssetControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else if (detail.capability.blocksEntirePage)
          LoopUnavailableLine(
            key: const ValueKey<String>('token-asset-blocked'),
            label: context.l10n.market_tokenTokenAssetBlockedLabel,
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
              message: context.l10n.market_tokenTokenLiveSuppressedMessage(
                loopReasonCodeText(
                  detail.capability.reasonCode ??
                      'BSC_CHAIN_RUNTIME_UNAVAILABLE',
                ),
              ),
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
              label: context.l10n.market_tokenTokenChartExpandLabel,
              onPressed: () => _open(MarketAssetRoute.chart(assetId)),
            ),
          ),
          // 持有者 / 动态 / 关于. Switching a tab changes what is listed and
          // nothing else; 动态 reads its trades the first time it opens.
          MarketTabBar(
            key: const ValueKey<String>('token-section-tabs'),
            keyPrefix: 'token-tab',
            ids: <String>[for (final tab in TokenSectionTab.values) tab.name],
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
                  label: context.l10n.common_swap,
                  primary: true,
                  block: true,
                  onPressed: () => _open('/wallet/swap'),
                )
              else
                LoopInlineUnavailable(
                  key: const ValueKey<String>('token-swap-unavailable'),
                  // A closed gate is the whole app's answer and outranks this
                  // asset's own.
                  message: context.l10n.market_tokenTokenSwapUnavailableMessage(
                    loopReasonCodeText(swapBlockedReason),
                  ),
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
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          0,
        ),
        child: Row(
          children: <Widget>[
            Text(
              LoopL10n.current.market_tokenHolderSections,
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
      LoopInlineUnavailable(
        key: ValueKey<String>('token-holders-distribution-unavailable'),
        icon: 'info',
        message: LoopL10n
            .current
            .market_tokenTokenHoldersDistributionUnavailableMessage,
      ),
      _factsProvenance(
        key: const ValueKey<String>('token-holders-provenance'),
        facts: <LoopFact>[count],
        prefix: LoopL10n.current.market_tokenHolderSections,
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
          emptyMessage: LoopL10n.current.common_noTradesYet,
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    switch (block) {
      case MarketTradesUnavailable(reasonCode: final reasonCode):
        return <Widget>[
          LoopInlineUnavailable(
            key: const ValueKey<String>('token-trades-unavailable'),
            message: LoopL10n.current.market_tokenTokenTradesUnavailableMessage(
              loopReasonCodeText(reasonCode),
            ),
          ),
        ];
      case MarketTradesAvailable(:final items) when items.isEmpty:
        return <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('token-trades-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: LoopL10n.current.common_noTradesYet,
            message: LoopL10n.current.market_tokenTokenTradesEmptyMessage,
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
              message: LoopL10n.current.common_nextPageFailed,
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
      prefix: LoopL10n.current.market_secondaryScreensLoopProvenanceFooter(
        loopGroupedFigure(freshness.indexerBlockNumber.toString()),
      ),
      detail: <String>[
        if (lag != null)
          LoopL10n.current.market_tokenLoopProvenanceLine(
            loopGroupedFigure(lag.toString()),
          ),
        LoopL10n.current.market_tokenLoopProvenanceLine2,
      ].join(LoopL10n.current.market_tokenSentenceGap),
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
      LoopLabel(LoopL10n.current.market_tokenLoopLabel),
      MarketQuoteCells(
        key: const ValueKey<String>('token-about-cells'),
        cells: <MarketStatCell>[
          marketRangeCell(
            LoopL10n.current.market_tokenMarketRangeCell,
            detail.range24h,
            high: true,
          ),
          marketRangeCell(
            LoopL10n.current.market_tokenMarketRangeCell2,
            detail.range24h,
            high: false,
          ),
          MarketStatCell.fact(
            LoopL10n.current.market_tokenFact,
            detail.volume24h,
            formatter: loopFormatCompactFigure,
          ),
        ],
      ),
      MarketQuoteCells(
        key: const ValueKey<String>('token-about-cells-2'),
        cells: <MarketStatCell>[
          MarketStatCell.fact(
            LoopL10n.current.common_liquidity,
            detail.liquidityUsd,
            formatter: loopFormatCompactFigure,
          ),
          MarketStatCell.fact(
            LoopL10n.current.market_tokenFact2,
            detail.fdv,
            formatter: loopFormatCompactFigure,
          ),
          MarketStatCell.fact(
            LoopL10n.current.common_marketCap,
            detail.marketCap,
            formatter: loopFormatCompactFigure,
          ),
        ],
      ),
      if (asset != null)
        LoopKeyValue(
          key: const ValueKey<String>('token-about-contract'),
          label: LoopL10n.current.common_contract,
          value: asset.address == null
              ? LoopL10n.current.market_tokenTokenAboutContractValue
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
      LoopLabel(LoopL10n.current.common_community),
      _CommunityBlock(
        block: detail.community,
        onOpenCommunity: (communityId) => _open(
          '/community/profile?id=${Uri.encodeQueryComponent(communityId)}',
        ),
      ),
      if (miningWeight != null)
        LoopPowerHint(
          key: const ValueKey<String>('token-mining-weight'),
          text: LoopL10n.current.market_tokenTokenMiningWeightText,
          figure: miningWeight.label,
          onTap: () => _open('/mining'),
        ),
      LoopLabel(LoopL10n.current.market_tokenLoopLabel2),
      TokenPoolAndContractFacts(
        pair: detail.primaryPair,
        security: detail.security,
      ),
      LoopLabel(LoopL10n.current.common_notifications),
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
      // S278 · decision 0236: the line is behind (i); the marker is not.
      marker: marked ? LoopL10n.current.market_tokenMarker : null,
      prefix:
          <String>[
            ?prefix,
            if (marked) LoopL10n.current.market_tokenMarker,
          ].join(' · ').isEmpty
          ? null
          : <String>[
              ?prefix,
              if (marked) LoopL10n.current.market_tokenMarker,
            ].join(' · '),
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
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 0, 8, 0),
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
              label: context.l10n.market_tokenTokenCopyAddressLabel,
              onPressed: () async {
                await LoopCopy.text(
                  context,
                  address,
                  message: context.l10n.market_tokenMessage2,
                );
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
        ? context.l10n.market_tokenBuild(
            loopReasonCodeSummaryText(change.reasonCode),
          )
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
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        6,
        LoopSpacing.page,
        4,
      ),
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
                    message: context.l10n
                        .market_tokenTokenPriceUnavailableMessage(
                          loopReasonCodeSummaryText(price.reasonCode),
                          loopReasonCodeText(price.reasonCode),
                        ),
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
                  // R7 a move at 600, as the MEME token page (decision 0190 M26).
                  style:
                      LoopTypography.withWeight(
                        LoopType.figureSm,
                        FontWeight.w600,
                      ).copyWith(
                        color: changeValue == null
                            ? LoopColors.text3
                            : move.color,
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
                context.l10n.common_marketCap,
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
        if (trade.isOwn) context.l10n.common_me,
        buy ? context.l10n.common_buy : context.l10n.common_sell,
        '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} ${trade.quoteSymbol}',
        loopFormatDecimal(trade.amountAsset),
        loopConfirmationLabel(trade.status),
        loopRelativeTime(trade.blockTimestamp),
      ].join(LoopL10n.current.common_listSeparator),
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
                buy ? context.l10n.common_buy : context.l10n.common_sell,
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
                      if (trade.isOwn) context.l10n.common_me,
                      loopRelativeTime(trade.blockTimestamp),
                      loopConfirmationLabel(trade.status),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // R5 (decision 0190 H7).
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
            ),
            if (reorged) ...<Widget>[
              LoopBadge(context.l10n.common_reverted, kind: LoopBadgeKind.down),
              const SizedBox(width: 6),
            ],
            Text(
              loopFormatDecimal(trade.amountAsset, maxFractionDigits: 4),
              maxLines: 1,
              // The row's second figure: the caption size (decision 0229).
              style: LoopType.figureSm,
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
    return Column(
      key: const ValueKey<String>('token-chart-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopChartToolbar(
          keyPrefix: 'token',
          averagesText: _averages ? loopChartAveragesText(candles) : '',
          style: _style,
          averages: _averages,
          volume: _volume,
          onStyleChanged: (style) => setState(() => _style = style),
          onAveragesChanged: (on) => setState(() => _averages = on),
          onVolumeChanged: (on) => setState(() => _volume = on),
        ),
        if (!state.isReady || block == null)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            child: LoopChainStateBlock(
              keyPrefix: 'candles',
              phase: state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.chart,
              emptyMessage: context.l10n.market_tokenEmptyMessage2,
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
                  message: context.l10n.market_tokenCandlesUnavailableMessage(
                    loopReasonCodeText(reasonCode),
                  ),
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
                child: Center(
                  child: LoopEmptyState(
                    showMessage: true,
                    key: ValueKey<String>('candles-empty'),
                    illustration: LoopIllustration.chartEmpty,
                    title: context.l10n.market_tokenEmptyMessage2,
                    message: context.l10n.market_tokenCandlesEmptyMessage,
                    compact: true,
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
              semanticLabel: context.l10n
                  .market_tokenTokenCandleChartSemanticLabel(
                    block.items.last.isOpen
                        ? context.l10n.market_tokenCandleLastOpen
                        : '',
                    loopChartIntervalLabel(widget.interval),
                    block.items.length,
                    block.priceUnit,
                    _style == LoopChartStyle.line
                        ? context.l10n.market_tokenCandleStyleLine
                        : context.l10n.market_tokenCandleStyleCandle,
                  ),
            ),
          },
        LoopChartIntervalRow(
          options: <LoopChartIntervalOption>[
            for (final interval in LoopCandleInterval.values)
              (
                keyName: 'token-interval-${interval.wireName}',
                label: loopChartIntervalLabel(interval),
              ),
          ],
          selectedIndex: LoopCandleInterval.values.indexOf(widget.interval),
          onSelected: (index) =>
              widget.onIntervalChanged(LoopCandleInterval.values[index]),
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
      // S278 · decision 0236: the line is behind (i); the quality marker and
      // the price unit (never USD by default) are not.
      marker: <String>[
        ?marker,
        context.l10n.market_tokenLoopProvenanceLine3(block.priceUnit),
      ].join(' · '),
      prefix: <String>{
        ?marker,
        if (block.hasSourceLabel) marketCandleLabelText(block.labelKey),
        // A provider top pool is not one LOOP indexes (decision 0064): the
        // line says so, so the chart never implies a trade feed.
        if (block.pool.isProviderPool)
          context.l10n.market_tokenLoopProvenanceLine4,
        if (open) context.l10n.market_tokenLoopProvenanceLine5,
        context.l10n.market_tokenLoopProvenanceLine3(block.priceUnit),
      }.join(' · '),
      sources: <String>[loopFactSourceLabel(block.source)],
      observedAt: block.fetchedAt,
      detail: <String>[
        context.l10n.market_tokenCandleSourceSentence(
          marketCandleSourcePoolText(block.source, block.pool),
        ),
        if (open) context.l10n.market_tokenLoopProvenanceLine6,
        context.l10n.market_tokenLoopProvenanceLine7,
      ].join(context.l10n.market_tokenSentenceGap),
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
    final style = LoopType.caption.copyWith(color: LoopColors.text2);
    final resolved = pair;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Text(
          resolved == null
              ? context.l10n.market_tokenTokenFactsPair
              : context.l10n.market_tokenTokenFactsPair2(
                  marketDexLabel(resolved.dexId),
                  resolved.quoteTokenSymbol,
                  loopTruncatedAddress(resolved.pairAddress),
                ),
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
            message: context.l10n.market_tokenTokenSecurityUnavailableMessage(
              loopReasonCodeText(reasonCode),
            ),
          ),
        );
      case MarketSecurityAvailable(facts: final facts) when facts.isEmpty:
        children.add(
          LoopInlineUnavailable(
            key: ValueKey<String>('token-security-empty'),
            icon: 'info',
            message: context.l10n.market_tokenTokenSecurityEmptyMessage,
          ),
        );
      case MarketSecurityAvailable(facts: final facts):
        final ordered = tokenSecurityFactsInTrayOrder(facts);
        children.add(
          Padding(
            key: const ValueKey<String>('token-security-facts'),
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
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
            prefix: context.l10n.market_tokenTokenSecurityProvenancePrefix(
              facts.length,
            ),
            sources: sources,
            observedAt: oldest,
            detail: context.l10n.market_tokenTokenSecurityProvenanceDetail,
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
    'openSource' => yesNo(
      LoopL10n.current.market_tokenYesNo,
      LoopL10n.current.market_tokenYesNo2,
    ),
    'proxy' => yesNo(
      LoopL10n.current.market_tokenYesNo3,
      LoopL10n.current.market_tokenYesNo4,
    ),
    'mintable' => yesNo(
      LoopL10n.current.market_tokenYesNo5,
      LoopL10n.current.market_tokenYesNo6,
    ),
    'ownershipTakeBack' => yesNo(
      LoopL10n.current.market_tokenYesNo7,
      LoopL10n.current.market_tokenYesNo8,
    ),
    'ownerChangeBalance' => yesNo(
      LoopL10n.current.market_tokenYesNo9,
      LoopL10n.current.market_tokenYesNo10,
    ),
    'hiddenOwner' => yesNo(
      LoopL10n.current.market_readModelsYesNo11,
      LoopL10n.current.market_readModelsYesNo12,
    ),
    'selfDestruct' => yesNo(
      LoopL10n.current.market_tokenYesNo11,
      LoopL10n.current.market_tokenYesNo12,
    ),
    'externalCall' => yesNo(
      LoopL10n.current.market_readModelsYesNo15,
      LoopL10n.current.market_readModelsYesNo16,
    ),
    'honeypot' => yesNo(
      LoopL10n.current.market_readModelsYesNo17,
      LoopL10n.current.market_readModelsYesNo18,
    ),
    'transferPausable' => yesNo(
      LoopL10n.current.market_tokenYesNo13,
      LoopL10n.current.market_tokenYesNo14,
    ),
    'blacklist' => yesNo(
      LoopL10n.current.market_tokenYesNo15,
      LoopL10n.current.market_tokenYesNo16,
    ),
    'whitelist' => yesNo(
      LoopL10n.current.market_tokenYesNo17,
      LoopL10n.current.market_tokenYesNo18,
    ),
    'antiWhale' => yesNo(
      LoopL10n.current.market_readModelsYesNo25,
      LoopL10n.current.market_readModelsYesNo26,
    ),
    'tradingCooldown' => yesNo(
      LoopL10n.current.market_readModelsYesNo27,
      LoopL10n.current.market_readModelsYesNo28,
    ),
    'cannotSellAll' => yesNo(
      LoopL10n.current.market_tokenYesNo19,
      LoopL10n.current.market_tokenYesNo20,
    ),
    'listedOnDex' => yesNo(
      LoopL10n.current.market_readModelsYesNo31,
      LoopL10n.current.market_readModelsYesNo32,
    ),
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
                // Decision 0171 (docs/33 L5): a risk fact is marked in the
                // accent (Lime then, Yellow since decision 0210), never the
                // v1 warning colour; S241b makes the mark square.
                color: risk ? LoopColors.yellow : LoopColors.text3,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tokenSecurityFactShortText(fact),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption.copyWith(
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
          message: context.l10n.market_tokenTokenCommunityUnavailableMessage(
            loopReasonCodeText(reasonCode),
          ),
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
              leading: const LoopRowIcon(icon: 'community'),
              title: context.l10n.market_tokenTokenCommunityEntryTitle,
              subtitle: context.l10n.market_tokenTokenCommunityEntrySubtitle(
                memberCount,
                name,
              ),
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
        emptyMessage: context.l10n.market_tokenEmptyMessage3,
        onRetry: () => unawaited(
          ref.read(notificationFeedControllerProvider.notifier).reload(),
        ),
      );
    }
    final entries = feed.priceAlerts
        .where((entry) => entry.contextParams['assetId'] == widget.assetId)
        .toList(growable: false);
    if (entries.isEmpty) {
      return LoopEmptyState(
        key: ValueKey<String>('token-feed-empty'),
        illustration: LoopIllustration.chartEmpty,
        title: context.l10n.market_tokenEmptyMessage3,
        message: context.l10n.market_tokenTokenFeedEmptyMessage,
        compact: true,
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
            trailingBadge: entry.isUnread
                ? LoopBadge(context.l10n.common_unread)
                : null,
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
    return LoopL10n.current.market_tokenIf;
  }
  return LoopL10n.current.market_tokenIf2(observed, symbol, threshold);
}

String _notificationDetail(LoopNotificationEntry entry) {
  final source = loopNotificationSourceLabel(entry.source);
  final observedAt = entry.observedAt;
  return <String>[
    ?source,
    if (observedAt != null)
      LoopL10n.current.community_aiBuild2(loopRelativeTime(observedAt)),
  ].join(' · ');
}
