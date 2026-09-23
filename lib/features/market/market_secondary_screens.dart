import 'dart:async';
import 'dart:math' as math;

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
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Shared capability gate for the four secondary market pages.
bool _marketBlocked(WidgetRef ref) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.marketRead),
  );
  final mode = ref.watch(marketReadGatewayProvider).mode;
  return loopChainCapabilityBlocks(mode, capability);
}

/// The whole-page block a closed market gate renders. It keeps the server's
/// own reason when the server answered, and says the client never reached LOOP
/// when it did not.
Widget _marketPageBlock(
  WidgetRef ref, {
  required Key key,
  required String title,
}) => LoopCapabilityPageBlock.of(
  key: key,
  title: title,
  capability: ref.watch(loopCapabilityProvider(LoopV2CapabilityId.marketRead)),
  fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
);

Widget _invalidAssetPage(String title, VoidCallback? onBack) => LoopFocusPage(
  key: ValueKey<String>('invalid-asset-$title'),
  archetype: LoopPageArchetype.record,
  title: title,
  onBack: onBack,
  body: const <Widget>[
    LoopEmpty(
      key: ValueKey<String>('invalid-asset-identity'),
      icon: 'warn',
      message: '路由中没有可用的资产标识',
      reason: '本页只接受规范的 CAIP assetId。未请求任何行情，也没有回退到其他资产。',
    ),
  ],
);

// ---------------------------------------------------------------------------
// chart-full
// ---------------------------------------------------------------------------

/// `chart-full` · the full-screen chart for one asset.
///
/// The interval segments map one-to-one onto the contract's `interval` values.
/// The prototype's `1m` segment and its MA / EMA / MACD / RSI / drawing tools
/// have no backend, so they are rendered as unavailable rather than as
/// controls that would silently do nothing.
class FullChartScreen extends ConsumerStatefulWidget {
  const FullChartScreen({required this.assetId, super.key, this.onBack});

  final String? assetId;
  final VoidCallback? onBack;

  @override
  ConsumerState<FullChartScreen> createState() => _FullChartScreenState();
}

class _FullChartScreenState extends ConsumerState<FullChartScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;

  /// `.kline-tools`: MA and VOL are drawn from the closes already on screen,
  /// so they can be switched here. EMA, MACD and RSI are not drawn by
  /// anything — there is no implementation and no source — so they are not
  /// rendered at all. A greyed chip for a feature nobody is building reads as
  /// a control that is temporarily broken; an absent one says nothing, which
  /// is the truth.
  static const List<int> _maPeriods = <int>[7, 25];
  bool _movingAverages = true;
  bool _volume = true;

  /// Everything on this page that is not the chart: the top bar, the OHLC and
  /// MA readouts above the plot, the card's own padding, the interval row,
  /// the indicator row and the provenance line under it. Measured against the
  /// rendered page rather than guessed — the chart takes whatever is left.
  static const double _chromeHeight = 340;

  /// Below this the plot stops being a chart and becomes a stripe, so the
  /// page scrolls instead of shrinking further.
  static const double _minimumChartHeight = 200;

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage('无法打开这张 K 线', widget.onBack);
    }
    if (_marketBlocked(ref)) {
      return LoopFocusPage(
        key: const ValueKey<String>('chart-full-blocked'),
        archetype: LoopPageArchetype.record,
        title: '全屏 K 线',
        onBack: widget.onBack,
        block: _marketPageBlock(
          ref,
          key: const ValueKey<String>('chart-full-capability-block'),
          title: '行情模块当前不可用',
        ),
        body: const <Widget>[],
      );
    }
    // The prototype's top bar is `PEPE` over `$0.0000082 +12.4%`; LOOP put
    // the page's own name in the title slot and the contract address above it
    // (audit 2026-09-21 §G.3). Both lines come from the asset read this page
    // already shares with the token page behind it.
    final identity = ref.watch(marketAssetControllerProvider(assetId));
    if (identity.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketAssetControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final detail = identity.value;
    final price = detail?.price;
    final change = detail?.priceChange24h;
    final quote = <String>[
      if (price != null && price.isAvailable) loopFormatUsd(price.value!),
      if (change != null && change.isAvailable)
        loopFormatPercent(change.value!),
    ].join(' ');

    // 「全屏 K 线」 drew a 320pt plot with a third of a screen of black under
    // it, in portrait, on a page whose whole purpose is the chart. The plot
    // takes the height the page actually has — in either orientation, so
    // turning the device sideways gives a landscape chart rather than a
    // letterboxed one.
    final media = MediaQuery.of(context);
    final chartHeight = math.max(
      _minimumChartHeight,
      media.size.height - media.padding.vertical - _chromeHeight,
    );

    return LoopFocusPage(
      key: ValueKey<String>('chart-full-$assetId'),
      archetype: LoopPageArchetype.record,
      title: detail == null
          ? loopTruncatedAssetId(assetId)
          : marketAssetIdentityLabel(detail.asset),
      subtitle: quote.isEmpty ? loopTruncatedAssetId(assetId) : quote,
      onBack: widget.onBack,
      body: <Widget>[
        TokenCandleSection(
          key: const ValueKey<String>('chart-full-candles'),
          assetId: assetId,
          interval: _interval,
          height: chartHeight,
          movingAveragePeriods: _movingAverages ? _maPeriods : const <int>[],
          showVolume: _volume,
          onIntervalChanged: (value) => setState(() => _interval = value),
          footer: MarketSegmentBar(
            key: const ValueKey<String>('chart-full-indicators'),
            labels: const <String>['MA', 'VOL'],
            selectedIndices: <int>{if (_movingAverages) 0, if (_volume) 1},
            enabled: const <bool>[true, true],
            onSelected: (index) => setState(() {
              if (index == 0) _movingAverages = !_movingAverages;
              if (index == 1) _volume = !_volume;
            }),
          ),
        ),
        const LoopNotice(
          key: ValueKey<String>('chart-full-interval-notice'),
          title: '这张图能做什么',
          body:
              '可选周期为 15m / 1H / 4H / 1D / 1W，1m 暂时不可用。'
              'MA 与 VOL 由本机按这张图上的收盘价与成交量计算，没有单独的数据来源；'
              '除此之外没有其他指标，也没有画线工具。',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// token-holders
// ---------------------------------------------------------------------------

/// `token-holders` · only the holder count has a source in this step.
class HolderDistributionScreen extends ConsumerStatefulWidget {
  const HolderDistributionScreen({
    required this.assetId,
    super.key,
    this.onBack,
  });

  final String? assetId;
  final VoidCallback? onBack;

  @override
  ConsumerState<HolderDistributionScreen> createState() =>
      _HolderDistributionScreenState();
}

class _HolderDistributionScreenState
    extends ConsumerState<HolderDistributionScreen> {
  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage('无法打开持有人分布', widget.onBack);
    }
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketHoldersControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketHoldersControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final holders = state.value;
    final count = holders?.holderCount;
    // Distribution is unavailable for the whole of this step, so a holder
    // count the server could not give leaves the page with nothing but two
    // refusals under a heading that repeats one of them (C-19). That is a
    // whole-page state, and it belongs in the page's own block rather than in
    // a card with a screen of black under it.
    final nothingToShow = holders != null && !holders.holderCount.isAvailable;

    return LoopDashboardPage(
      key: ValueKey<String>('token-holders-$assetId'),
      onRefresh: ref
          .read(marketHoldersControllerProvider(assetId).notifier)
          .reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: '持有人分布',
      onBack: widget.onBack,
      // `.folio-primary.chalk-card`: the prototype's Chalk hero. LOOP drew
      // the same Lime hero it uses everywhere, so the whole module read as
      // one colour (audit 2026-09-21 §G.4, §D item 2).
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-holders-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: 'HOLDER LEDGER',
        heading: count == null || count.value == null
            ? '持有人总数不可用'
            : '${loopFormatDecimal(count.value!, maxFractionDigits: 0)} 持有人',
        caption: count == null
            ? '持有人事实尚未读取成功。'
            : count.isAvailable
            ? loopFactProvenance(count)
            : loopReasonCodeText(count.reasonCode),
        stamp: count != null && count.isAvailable
            ? loopFormatDecimal(count.value!, maxFractionDigits: 0)
            : null,
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('token-holders-capability-block'),
              title: '行情模块当前不可用',
            )
          : nothingToShow
          ? LoopPageBlock(
              key: const ValueKey<String>('token-holders-page-block'),
              title: '持有人分布当前不可用',
              message: loopReasonCodeText(holders.holderCount.reasonCode),
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || holders == null)
          LoopChainStateBlock(
            keyPrefix: 'token-holders',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref
                  .read(marketHoldersControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          // `.stat-grid`: the prototype's two cells. The concentration half
          // has no source in this step and says so in the figure's place,
          // which keeps the grid's shape without printing a zero.
          MarketStatGrid(
            key: const ValueKey<String>('token-holders-stats'),
            cells: <MarketStatCell>[
              MarketStatCell.fact(
                '持有人总数',
                holders.holderCount,
                formatter: (value) =>
                    loopFormatDecimal(value, maxFractionDigits: 0),
              ),
              MarketStatCell(
                label: 'Top 10 集中度',
                value: loopReasonCodeSummaryText(
                  holders.distribution.reasonCode,
                ),
                available: false,
              ),
            ],
          ),
          const LoopLabel('持有人总数'),
          LoopSurfaceCard(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopFactLine(
              label: '持有人总数',
              fact: holders.holderCount,
              emphasize: true,
              formatter: (value) =>
                  loopFormatDecimal(value, maxFractionDigits: 0),
            ),
          ),
          const LoopLabel('分布'),
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('token-holders-distribution'),
            label: 'Top 持有人、集中度与聚类标注不可用',
            fact: holders.distribution,
          ),
          const LoopNotice(
            key: ValueKey<String>('token-holders-notice'),
            title: '没有分布就不画分布',
            body: '前十 / 前百集中度暂时读不到，这里不显示任何比例或地址。',
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// token-trades
// ---------------------------------------------------------------------------

/// `token-trades` · the indexed pool swap tape.
///
/// The backend sends no counterparty address: `isOwn` is the only identity
/// fact. The prototype's 大单 segment is a local threshold filter on
/// `amountQuote`; its 聪明钱 segment has no backend and stays disabled.
class TradingActivityScreen extends ConsumerStatefulWidget {
  const TradingActivityScreen({required this.assetId, super.key, this.onBack});

  final String? assetId;
  final VoidCallback? onBack;

  /// The local threshold that marks a trade as 大单. It is a client-side view
  /// filter, never a server fact.
  static final Decimal largeTradeQuoteThreshold = Decimal.fromInt(10000);

  @override
  ConsumerState<TradingActivityScreen> createState() =>
      _TradingActivityScreenState();
}

class _TradingActivityScreenState extends ConsumerState<TradingActivityScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage('无法打开交易活动', widget.onBack);
    }
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketTradesControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketTradesControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final page = state.value;
    final block = page?.trades;

    return LoopDashboardPage(
      key: ValueKey<String>('token-trades-$assetId'),
      onRefresh: ref
          .read(marketTradesControllerProvider(assetId).notifier)
          .reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: '交易活动',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-trades-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: 'ACTIVITY TAPE',
        heading: block is MarketTradesAvailable
            ? '${block.items.length} 笔链上成交'
            : '最新链上成交记录',
        caption: '方向、数量和时间按同一节奏扫描，来自已登记 PancakeSwap V3 池的 Swap 事件。',
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('token-trades-capability-block'),
              title: '行情模块当前不可用',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || block == null)
          LoopChainStateBlock(
            keyPrefix: 'token-trades',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref
                  .read(marketTradesControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else
          ...switch (block) {
            MarketTradesUnavailable(reasonCode: final reasonCode) => <Widget>[
              LoopUnavailableCard(
                key: const ValueKey<String>('token-trades-unavailable'),
                label: '成交记录不可用',
                reasonCode: reasonCode,
              ),
            ],
            MarketTradesAvailable() => _tradeSections(block),
          },
      ],
    );
  }

  List<Widget> _tradeSections(MarketTradesAvailable block) {
    final visible = _segment == 1
        ? block.items
              .where(
                (trade) =>
                    trade.amountQuote >=
                    TradingActivityScreen.largeTradeQuoteThreshold,
              )
              .toList(growable: false)
        : block.items;
    return <Widget>[
      MarketSegmentBar(
        labels: const <String>['全部', '大单', '聪明钱'],
        selectedIndex: _segment,
        enabled: const <bool>[true, true, false],
        onSelected: (index) => setState(() => _segment = index),
        blockedMessages: <String?>[
          null,
          null,
          loopReasonCodeText('SMART_MONEY_RUNTIME_DEFERRED'),
        ],
      ),
      if (_segment == 2)
        const LoopUnavailableCard(
          key: ValueKey<String>('token-trades-smart-money'),
          label: '聪明钱筛选不可用',
          reasonCode: 'SMART_MONEY_RUNTIME_DEFERRED',
        )
      else if (visible.isEmpty)
        LoopEmpty(
          key: const ValueKey<String>('token-trades-empty'),
          message: _segment == 1 ? '这一页没有大单' : '这一页没有成交',
          reason: _segment == 1
              ? '大单是按成交金额在本机筛出来的，不是官方标注。'
              : '索引器已经读到这个区间，但其中没有成交。',
        )
      else
        LoopRecordGroup(
          rows: <LoopRecordRow>[for (final trade in visible) _tradeRow(trade)],
        ),
      _FreshnessFooter(freshness: block.freshness),
      const LoopNotice(
        key: ValueKey<String>('token-trades-notice'),
        title: '不下发对手方地址',
        body: '这里只能标出哪一笔是你自己的钱包发起的。"大单"是按金额在本机筛出来的，"聪明钱"暂时没有数据。',
      ),
    ];
  }

  LoopRecordRow _tradeRow(MarketTrade trade) {
    final isBuy = trade.direction == MarketTradeDirection.buy;
    final isLarge =
        trade.amountQuote >= TradingActivityScreen.largeTradeQuoteThreshold;
    return LoopRecordRow(
      key: ValueKey<String>('trade-${trade.tradeId}'),
      // `.row-ico` with the direction arrow: the prototype's tape is read by
      // its leading marks before it is read by its words.
      leading: MarketDirectionAvatar(inbound: isBuy),
      title:
          '${isBuy ? '买入' : '卖出'} '
          '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} '
          '${trade.quoteSymbol}',
      subtitle: <String>[
        if (trade.isOwn) '我',
        loopConfirmationLabel(trade.status),
        if (trade.confirmations != null)
          '${loopGroupedFigure(trade.confirmations.toString())} 确认',
        '区块 ${loopGroupedFigure(trade.blockNumber.toString())}',
        loopRelativeTime(trade.blockTimestamp),
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: loopFormatDecimal(trade.amountAsset),
      trailingCaptionUp: isBuy,
      trailingCaption: isBuy ? '流出池' : '流入池',
      trailingBadge: trade.status == LoopConfirmationStatus.reorged
          ? const LoopBadge('已回滚', kind: LoopBadgeKind.down)
          : isLarge
          ? const LoopBadge('大单')
          : null,
    );
  }
}

class _FreshnessFooter extends StatelessWidget {
  const _FreshnessFooter({required this.freshness});

  final LoopIndexerFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final lag = freshness.lagBlocks;
    return LoopProvenanceFooter(
      key: const ValueKey<String>('indexer-freshness'),
      text: <String>[
        // The block number on the same line already groups; a figure that
        // does not reads as a different kind of number.
        '索引高度 ${loopGroupedFigure(freshness.indexerBlockNumber.toString())}',
        if (lag != null) '数据落后 ${loopGroupedFigure(lag.toString())} 块',
        '观察于 ${loopRelativeTime(freshness.observedAt)}',
      ].join(' · '),
    );
  }
}

// ---------------------------------------------------------------------------
// new-pairs
// ---------------------------------------------------------------------------

/// `new-pairs` · GeckoTerminal is disabled by default, so the whole page is
/// unavailable and states the server's `reasonCode`.
class NewPairsScreen extends ConsumerStatefulWidget {
  const NewPairsScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<NewPairsScreen> createState() => _NewPairsScreenState();
}

class _NewPairsScreenState extends ConsumerState<NewPairsScreen> {
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
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketNewPairsControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(marketNewPairsControllerProvider.notifier).load());
        }
      });
    }
    final page = state.value;
    final block = page?.newPairs;

    return LoopDashboardPage(
      key: const ValueKey<String>('new-pairs-screen'),
      onRefresh: ref.read(marketNewPairsControllerProvider.notifier).reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: '新币发现',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('new-pairs-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: 'NEW PAIRS',
        heading: block is MarketNewPairsAvailable
            ? '${block.items.length} 个新对 · 高风险'
            : '新币发现',
        caption: '先看流动性、合约状态与数据出处，再看短期价格。',
        // `.folio-stamp`: this page's subject is the risk, and the stamp is
        // where the prototype states it.
        stamp: 'HIGH RISK',
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('new-pairs-capability-block'),
              title: '行情模块当前不可用',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || page == null || block == null)
          LoopChainStateBlock(
            keyPrefix: 'new-pairs',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref.read(marketNewPairsControllerProvider.notifier).reload(),
            ),
          )
        else
          ...switch (block) {
            // No provider means the whole page is unavailable, with the
            // server's reason — never an empty list.
            MarketNewPairsUnavailable(reasonCode: final reasonCode) => <Widget>[
              LoopUnavailableCard(
                key: const ValueKey<String>('new-pairs-unavailable'),
                label: '新币发现不可用',
                reasonCode: reasonCode,
              ),
            ],
            MarketNewPairsAvailable() => <Widget>[
              if (block.items.isEmpty)
                const LoopEmpty(
                  key: ValueKey<String>('new-pairs-empty'),
                  message: '当前没有新的池',
                  reason: '这是数据本身的结果，不是筛选后的结论。',
                )
              else
                LoopRecordGroup(
                  rows: <LoopRecordRow>[
                    for (final pair in block.items)
                      LoopRecordRow(
                        key: ValueKey<String>(
                          'new-pair-${pair.poolRef.rowKey}',
                        ),
                        // `.row-ico`: every prototype row on this page is
                        // headed by the pool's own token mark (§D item 7).
                        // A pool whose Provider name was nothing but
                        // display-unsafe code points is left without one; the
                        // row still belongs to the reader, so it says the name
                        // is missing and falls back to the DEX for the mark.
                        leading: LoopTokenLogo(
                          assetSymbol: pair.name.isEmpty
                              ? pair.dexId
                              : pair.name,
                          fallbackMonogram: pair.name.isEmpty
                              ? pair.dexId
                              : pair.name,
                        ),
                        title: pair.name.isEmpty ? '未命名池' : pair.name,
                        subtitle: <String>[
                          // The provider's own DEX string, printed verbatim:
                          // it is not a closed set.
                          pair.dexId,
                          // A Uniswap V4 pool lives inside the singleton: it
                          // has no pair page, no chart and no address-keyed
                          // facts, so the row says so instead of offering a
                          // tap that would open nothing.
                          if (pair.poolRef is MarketPoolIdRef)
                            'Uniswap V4 池 · 暂不支持详情',
                          // The watchlist holds registry assets. A pool whose
                          // base token the registry does not carry has nothing
                          // to add, and the row says so rather than offering a
                          // star that would be refused.
                          if (pair.poolRef is MarketPoolAddressRef &&
                              pair.registryAssetId == null)
                            '暂不支持加自选',
                          // A zero quote address is the coin itself, not a
                          // missing token.
                          if (pair.quotesNativeCoin) '计价 BNB',

                          // A pool minutes old holds fractions of a dollar.
                          // Rounded to cents that printed 「$0」, which on a
                          // page that promises to say why a figure is missing
                          // rather than show a zero reads as "no liquidity at
                          // all" — a pulled pool. Bounding it at 「<$1」 was
                          // no better: a launchpad pool is quoted at 1e-6, so
                          // the bound is true of every row and tells the
                          // reader nothing. This row has the width for three
                          // significant digits, and that is the figure.
                          if (pair.reserveUsd != null)
                            '储备 '
                                '${loopFormatCompactFigure(pair.reserveUsd!, preciseBelowOne: true)}'
                          else
                            '储备暂时读不到',
                          // The trailing slot holds the 24-hour figure; when
                          // it is missing the row says so rather than leaving
                          // an empty corner the reader has to explain.
                          if (pair.volumeH24Usd == null) '24 小时成交额暂时读不到',
                        ].join(' · '),
                        subtitleMaxLines: 2,
                        trailingBadge: pair.registryAssetId == null
                            ? null
                            : _NewPairWatchAction(
                                assetId: pair.registryAssetId!,
                              ),
                        trailing: pair.volumeH24Usd == null
                            ? null
                            : loopFormatCompactFigure(
                                pair.volumeH24Usd!,
                                preciseBelowOne: true,
                              ),
                        // `.row-end .d`: the prototype's age column. It read
                        // as the fourth fact of a two-line subtitle before.
                        trailingCaption: pair.createdAt == null
                            ? null
                            : loopRelativeTime(pair.createdAt!),
                        onTap: !pair.opensDetail
                            ? null
                            : () => _open(
                                MarketAssetRoute.token(pair.registryAssetId!),
                              ),
                      ),
                  ],
                ),
              // Both identifier forms are listed now, so what is left out is
              // a row the provider sent in neither shape. It is normally zero;
              // when it is not, saying so keeps the page from passing a
              // partial list off as all of it.
              if (block.omittedCount > 0)
                LoopNotice(
                  key: const ValueKey<String>('new-pairs-omitted'),
                  title: '另有 ${block.omittedCount} 条数据无法解析',
                  body: '这些行的池标识既不是合约地址也不是 pool id，本页不展示无法核对的行。',
                ),
              LoopProvenanceFooter(
                text:
                    '来源 ${loopFactSourceLabel(block.source)} · '
                    '观察于 ${loopRelativeTime(block.fetchedAt)}',
              ),
            ],
          },
        if (page != null) ...<Widget>[
          const LoopLabel('风险预筛'),
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('new-pairs-risk-screening'),
            label: '风险预筛不可用',
            fact: page.riskScreening,
          ),
        ],
        const LoopNotice(
          key: ValueKey<String>('new-pairs-notice'),
          title: '预筛不等于结论',
          body: '读不到风险预筛数据时，这里不会自行判断风险。新池流动性薄，价格容易被操纵。',
          tone: LoopNoticeTone.warn,
        ),
      ],
    );
  }
}

/// The 加自选 action on one 新币发现 row.
///
/// The row could only be read before this. It writes through the same
/// controller the Token page's star does, so both say the same thing about
/// the same outcome, and it appears only where LOOP already knows which
/// registry asset the row's base token is: an address alone is not an asset
/// id, and the write would be refused as an unregistered asset.
///
/// The list is not read when the page opens. One document holds every
/// membership on this screen, and reading it once per row would be a hundred
/// reads of the same thing; the star therefore starts in its third state —
/// not known — and the first press reads before it writes, which is the
/// behaviour the star already documents.
class _NewPairWatchAction extends ConsumerWidget {
  const _NewPairWatchAction({required this.assetId});

  final String assetId;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(watchlistMembershipControllerProvider(assetId).notifier)
        .toggle();
    if (!context.mounted) return;
    showWatchlistToggleToast(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The watchlist is a different resource from the market read this page
    // ran on: its own capability and its own gateway decide this control, so
    // a market outage never claims an asset is unwatched.
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.watchlist),
    );
    final mode = ref.watch(watchlistGatewayProvider).mode;
    final membership = ref.watch(
      watchlistMembershipControllerProvider(assetId),
    );
    final blocked =
        loopChainCapabilityBlocks(mode, capability) ||
        membership.phase == LoopChainViewPhase.unavailable;
    return LoopIconButton(
      key: ValueKey<String>('new-pair-watchlist-$assetId'),
      icon: 'star',
      label: blocked ? '自选当前不可用' : membership.actionLabel,
      color: membership.isWatched ? LoopColors.lime : null,
      // An unread list has no on/off state to report; claiming `false` would
      // say the asset is not watched.
      toggled: blocked || !membership.isKnown ? null : membership.isWatched,
      onPressed: blocked || membership.busy
          ? null
          : () => unawaited(_toggle(context, ref)),
    );
  }
}

// ---------------------------------------------------------------------------
// smart-money
// ---------------------------------------------------------------------------

/// `smart-money` · always unavailable in this step (D21).
class SmartMoneyScreen extends ConsumerStatefulWidget {
  const SmartMoneyScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<SmartMoneyScreen> createState() => _SmartMoneyScreenState();
}

class _SmartMoneyScreenState extends ConsumerState<SmartMoneyScreen> {
  @override
  Widget build(BuildContext context) {
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketSmartMoneyControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketSmartMoneyControllerProvider.notifier).load(),
          );
        }
      });
    }
    final fact = state.value;

    return LoopFocusPage(
      key: const ValueKey<String>('smart-money-screen'),
      archetype: LoopPageArchetype.listing,
      title: '聪明钱追踪',
      onBack: widget.onBack,
      folio: const LoopFolioPrimary(
        key: ValueKey<String>('smart-money-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: 'PUBLIC WALLET WATCH',
        heading: '还没有可观察的地址',
        caption: '观察地址的动作是线索，不是跟单承诺或收益推荐。',
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('smart-money-capability-block'),
              title: '行情模块当前不可用',
            )
          : null,
      body: <Widget>[
        if (!state.isReady || fact == null)
          LoopChainStateBlock(
            keyPrefix: 'smart-money',
            phase: state.phase,
            failureKind: state.failureKind,
            rows: 1,
            onRetry: () => unawaited(
              ref.read(marketSmartMoneyControllerProvider.notifier).reload(),
            ),
          )
        else ...<Widget>[
          // The prototype's two groups, in its order. Neither is invented:
          // both state the server's own reason where its rows would be, so
          // the page keeps the shape it will have once the data exists.
          const LoopLabel('关注地址'),
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('smart-money-unavailable'),
            label: '关注地址不可用',
            fact: fact,
          ),
          const LoopLabel('最近动向'),
          // The server's own sentence is stated once, by the block above.
          // This one says what it depends on instead of repeating it.
          const LoopEmpty(
            key: ValueKey<String>('smart-money-moves-unavailable'),
            message: '还没有可列的动向',
            reason: '动向来自关注地址，而关注地址还没有开放。',
          ),
        ],
        const LoopNotice(
          key: ValueKey<String>('smart-money-notice'),
          title: '胜率不是预测',
          body: '即使开放，地址标签与胜率也只是公开链上数据的历史统计，不构成跟随建议。',
        ),
      ],
    );
  }
}
