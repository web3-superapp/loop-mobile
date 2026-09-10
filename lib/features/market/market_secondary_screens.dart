import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
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

String _marketBlockReason(WidgetRef ref) =>
    ref
        .watch(loopCapabilityProvider(LoopV2CapabilityId.marketRead))
        .reasonCode ??
    'MARKET_RUNTIME_UNAVAILABLE';

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
        body: <Widget>[
          LoopUnavailableCard(
            key: const ValueKey<String>('chart-full-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: _marketBlockReason(ref),
          ),
        ],
      );
    }
    return LoopFocusPage(
      key: ValueKey<String>('chart-full-$assetId'),
      archetype: LoopPageArchetype.record,
      title: '全屏 K 线',
      kicker: loopTruncatedAssetId(assetId),
      onBack: widget.onBack,
      body: <Widget>[
        TokenCandleSection(
          key: const ValueKey<String>('chart-full-candles'),
          assetId: assetId,
          interval: _interval,
          height: 320,
          onIntervalChanged: (value) => setState(() => _interval = value),
        ),
        const LoopLabel('指标与画线'),
        const LoopUnavailableCard(
          key: ValueKey<String>('chart-full-indicators-unavailable'),
          label: 'MA / EMA / MACD / RSI 与画线工具不可用',
          reasonCode: 'MARKET_CHART_TOOLS_DEFERRED',
        ),
        const LoopNotice(
          key: ValueKey<String>('chart-full-interval-notice'),
          title: '可选周期',
          body: '可选周期为 15m / 1H / 4H / 1D / 1W。1m 暂时不可用。',
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

    return LoopDashboardPage(
      key: ValueKey<String>('token-holders-$assetId'),
      archetype: LoopPageArchetype.listing,
      title: '持有人分布',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-holders-folio'),
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
      ),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('token-holders-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: _marketBlockReason(ref),
          )
        else if (!state.isReady || holders == null)
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
      archetype: LoopPageArchetype.listing,
      title: '交易活动',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-trades-folio'),
        archetype: LoopFolioArchetype.listing,
        kicker: 'ACTIVITY TAPE',
        heading: block is MarketTradesAvailable
            ? '${block.items.length} 笔链上成交'
            : '链上成交',
        caption: '来自已登记 PancakeSwap V3 池的 Swap 事件，每条带交易哈希、区块与确认状态。',
      ),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('token-trades-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: _marketBlockReason(ref),
          )
        else if (!state.isReady || block == null)
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
      title:
          '${isBuy ? '买入' : '卖出'} '
          '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} '
          '${trade.quoteSymbol}',
      subtitle: <String>[
        if (trade.isOwn) '我',
        loopConfirmationLabel(trade.status),
        if (trade.confirmations != null) '${trade.confirmations} 确认',
        '区块 ${trade.blockNumber}',
        loopRelativeTime(trade.blockTimestamp),
      ].join(' · '),
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
        '索引高度 ${freshness.indexerBlockNumber}',
        if (lag != null) '数据落后 $lag 块',
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
      archetype: LoopPageArchetype.listing,
      title: '新币发现',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('new-pairs-folio'),
        archetype: LoopFolioArchetype.listing,
        kicker: 'NEW PAIRS',
        heading: block is MarketNewPairsAvailable
            ? '${block.items.length} 个新对'
            : '新币发现',
        caption: '先看流动性、合约状态与数据出处，再看短期价格。',
      ),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('new-pairs-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: _marketBlockReason(ref),
          )
        else if (!state.isReady || page == null || block == null)
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
                        key: ValueKey<String>('new-pair-${pair.poolAddress}'),
                        title: pair.name,
                        subtitle: <String>[
                          pair.dexId,
                          if (pair.createdAt != null)
                            '创建于 ${loopRelativeTime(pair.createdAt!)}',
                          if (pair.reserveUsd != null)
                            '储备 ${loopFormatUsd(pair.reserveUsd!)}',
                        ].join(' · '),
                        trailing: pair.volumeH24Usd == null
                            ? null
                            : loopFormatUsd(pair.volumeH24Usd!),
                        onTap: pair.registryAssetId == null
                            ? null
                            : () => _open(
                                MarketAssetRoute.token(pair.registryAssetId!),
                              ),
                      ),
                  ],
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
        archetype: LoopFolioArchetype.listing,
        kicker: 'PUBLIC WALLET WATCH',
        heading: '暂未开放',
        caption: '这里不会展示任何地址、胜率或跟随建议。',
      ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('smart-money-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: _marketBlockReason(ref),
          )
        else if (!state.isReady || fact == null)
          LoopChainStateBlock(
            keyPrefix: 'smart-money',
            phase: state.phase,
            failureKind: state.failureKind,
            rows: 1,
            onRetry: () => unawaited(
              ref.read(marketSmartMoneyControllerProvider.notifier).reload(),
            ),
          )
        else
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('smart-money-unavailable'),
            label: '聪明钱追踪不可用',
            fact: fact,
          ),
        const LoopNotice(
          key: ValueKey<String>('smart-money-notice'),
          title: '胜率不是预测',
          body: '即使开放，地址标签与胜率也只是公开链上数据的历史统计，不构成跟随建议。',
        ),
      ],
    );
  }
}
