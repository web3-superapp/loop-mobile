import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markets = ref.watch(hyperliquidMarketsProvider);
    return LoopPage(
      eyebrow: 'C1 · Hyperliquid Testnet',
      title: 'Market pulse',
      subtitle: '实时公共市场数据只读。账户、仓位、订单与签名不经过这条移动端数据路径。',
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('refresh-live-markets'),
          onPressed: markets.isLoading
              ? null
              : () => ref.invalidate(hyperliquidMarketsProvider),
          tooltip: '刷新 Hyperliquid Testnet 行情',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        const Align(
          alignment: Alignment.centerLeft,
          child: LoopContextRail(stage: LoopStage.discover),
        ),
        const SizedBox(height: 14),
        const _LiveMarketBanner(),
        const SizedBox(height: 18),
        const _MarketModeControl(),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey<String>('live-market-search'),
          controller: _searchController,
          onChanged: (value) {
            setState(() => _query = value.trim().toUpperCase());
          },
          decoration: InputDecoration(
            hintText: '搜索市场，例如 BTC',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    tooltip: '清除搜索',
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                <(String, String)>[
                      ('Watchlist · 开发预览', '/market/watchlist'),
                      ('New · 开发预览', '/market/new'),
                      ('Smart money · 开发预览', '/market/smart-money'),
                      ('Perp trading · 开发预览', '/perp'),
                    ]
                    .map(
                      (destination) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(destination.$1),
                          onPressed: () => context.push(destination.$2),
                        ),
                      ),
                    )
                    .toList(growable: false),
          ),
        ),
        ...markets.when(
          loading: () => const <Widget>[
            SizedBox(height: 20),
            _LiveMarketLoading(),
          ],
          error: (error, stackTrace) => <Widget>[
            const SizedBox(height: 20),
            _LiveMarketError(
              message: _marketFailureMessage(error),
              onRetry: _isRestrictedSessionFailure(error) ? null : _retry,
            ),
          ],
          data: (items) {
            final visible = _query.isEmpty
                ? items
                : items
                      .where(
                        (market) =>
                            market.symbol.toUpperCase().contains(_query),
                      )
                      .toList(growable: false);
            if (visible.isEmpty) {
              return <Widget>[
                const SizedBox(height: 20),
                _LiveMarketEmpty(hasQuery: _query.isNotEmpty),
              ];
            }
            return <Widget>[
              LoopSectionLabel('Live perpetual markets · ${visible.length}'),
              _MarketLedgerHeader(total: items.length),
              const SizedBox(height: 10),
              for (var index = 0; index < visible.length; index++) ...<Widget>[
                _LiveMarketRow(
                  rank: index + 1,
                  market: visible[index],
                  onOpenDevelopmentPreview:
                      MarketPreviewData.coreAssets.any(
                        (asset) => asset.symbol == visible[index].symbol,
                      )
                      ? () => context.push(
                          '/market/token',
                          extra: visible[index].symbol,
                        )
                      : null,
                ),
                if (index != visible.length - 1) const SizedBox(height: 10),
              ],
            ];
          },
        ),
      ],
    );
  }

  void _retry() => ref.invalidate(hyperliquidMarketsProvider);
}

bool _isRestrictedSessionFailure(Object error) {
  return error is HyperliquidMarketFailure &&
      error.kind == HyperliquidMarketFailureKind.restrictedSession;
}

String _marketFailureMessage(Object error) {
  if (error case HyperliquidMarketFailure(kind: final kind)) {
    return switch (kind) {
      HyperliquidMarketFailureKind.restrictedSession =>
        '受限会话保持离线，完成 Privy 验证后可加载 Testnet 行情。',
      HyperliquidMarketFailureKind.timeout => '行情请求超时，请检查网络后重试。',
      HyperliquidMarketFailureKind.connection => '无法连接 Testnet，请检查网络。',
      HyperliquidMarketFailureKind.unavailable => 'Testnet 服务暂时不可用。',
      HyperliquidMarketFailureKind.cancelled => '行情请求已取消。',
      HyperliquidMarketFailureKind.invalidPayload => '行情响应格式异常，已拒绝展示。',
      HyperliquidMarketFailureKind.unexpected => '行情加载失败，请稍后重试。',
    };
  }
  return '行情加载失败，请稍后重试。';
}

class _LiveMarketBanner extends StatelessWidget {
  const _LiveMarketBanner();

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.market,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.science_outlined, color: LoopColors.market),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TESTNET · 实时公共数据 · 只读',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: LoopColors.market, letterSpacing: 0.85),
                ),
                const SizedBox(height: 5),
                Text(
                  '价格、24h 成交额与资金费率从 Hyperliquid 字符串精确解析；下单必须经过 Loop 后端。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMarketLoading extends StatelessWidget {
  const _LiveMarketLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '正在加载 Hyperliquid Testnet 行情',
      liveRegion: true,
      child: const LoopCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _LiveMarketError extends StatelessWidget {
  const _LiveMarketError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: '行情暂不可用',
      message: message,
      icon: Icons.cloud_off_outlined,
      tone: LoopTone.danger,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              key: const ValueKey<String>('retry-live-markets'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
    );
  }
}

class _LiveMarketEmpty extends StatelessWidget {
  const _LiveMarketEmpty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: hasQuery ? '没有匹配的市场' : '暂无可展示市场',
      message: hasQuery ? '尝试输入其他代币符号。' : 'Testnet 没有返回活跃市场，请稍后刷新。',
      icon: hasQuery ? Icons.search_off_rounded : Icons.inbox_outlined,
      tone: LoopTone.neutral,
    );
  }
}

class _LiveMarketRow extends StatelessWidget {
  const _LiveMarketRow({
    required this.rank,
    required this.market,
    this.onOpenDevelopmentPreview,
  });

  final int rank;
  final HyperliquidMarket market;
  final VoidCallback? onOpenDevelopmentPreview;

  @override
  Widget build(BuildContext context) {
    final fundingPercent = market.fundingRate.value * Decimal.fromInt(100);
    final fundingIsNegative = fundingPercent.compareTo(Decimal.zero) < 0;
    final fundingColor = fundingIsNegative
        ? LoopColors.danger
        : LoopColors.mint;
    final fundingLabel = '${fundingPercent.toStringAsFixed(4)}%';
    final detailsLabel = onOpenDevelopmentPreview == null
        ? 'Hyperliquid Testnet · max ${market.maxLeverage}×'
        : '实时列表 · 详情为开发预览';

    return LoopCard(
      onTap: onOpenDevelopmentPreview,
      semanticLabel: onOpenDevelopmentPreview == null
          ? null
          : 'Open ${market.symbol} development preview details; details are not live',
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontFamily: 'monospace', color: LoopColors.vapor),
            ),
          ),
          const SizedBox(width: 8),
          LoopAssetMark(symbol: market.symbol),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${market.symbol}-USD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  detailsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '24h ${_groupIntegerPart(market.dayNotionalVolume.source)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '\$${_groupIntegerPart(market.markPrice.source)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dataStyle,
                ),
                const SizedBox(height: 5),
                Text(
                  fundingLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fundingColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _groupIntegerPart(String source) {
  final sign = source.startsWith('-') ? '-' : '';
  final unsigned = sign.isEmpty ? source : source.substring(1);
  final parts = unsigned.split('.');
  final integer = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < integer.length; index += 1) {
    if (index > 0 && (integer.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(integer[index]);
  }
  if (parts.length == 1) return '$sign$grouped';
  return '$sign$grouped.${parts.sublist(1).join('.')}';
}

class _MarketModeControl extends StatelessWidget {
  const _MarketModeControl();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Market type. Hyperliquid Testnet perpetuals selected.',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: LoopColors.basalt,
          borderRadius: LoopRadius.medium,
          border: Border.all(color: LoopColors.line),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_outline_rounded, size: 17),
                label: const Text('Spot unavailable'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LoopColors.market.withValues(alpha: 0.12),
                  borderRadius: LoopRadius.small,
                  border: Border.all(
                    color: LoopColors.market.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'Perpetual',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: LoopColors.market),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketLedgerHeader extends StatelessWidget {
  const _MarketLedgerHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$total active assets · indexed payload',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Text(
          'MARK / FUNDING',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class TokenDetailScreen extends StatelessWidget {
  const TokenDetailScreen({
    super.key,
    this.symbol = 'ETH',
    this.snapshotState = MarketSnapshotState.preview,
  });

  final String symbol;
  final MarketSnapshotState snapshotState;

  @override
  Widget build(BuildContext context) {
    final asset = MarketPreviewData.asset(symbol);
    final hasFacts = snapshotState == MarketSnapshotState.preview;
    return LoopPage(
      eyebrow: 'C2 · 开发预览 · ${asset.pair}',
      title: asset.name,
      subtitle: '此详情页仍是演示数据，不是实时行情。图表与合约信息只读且不可执行。',
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/market/watchlist'),
          tooltip: 'Open watchlist preview',
          icon: const Icon(Icons.star_border_rounded),
        ),
        IconButton(
          onPressed: () => context.push('/market/alerts', extra: asset.symbol),
          tooltip: 'Open price alert preview',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
      children: <Widget>[
        MarketSnapshotBanner(state: snapshotState),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 20),
          MarketStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoopAssetMark(symbol: asset.symbol, size: 52),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      asset.price,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        LoopStatusPill(
                          label: '${asset.change} · 演示 24h',
                          tone: asset.isPositive
                              ? LoopTone.positive
                              : LoopTone.danger,
                          icon: asset.isPositive
                              ? Icons.north_east_rounded
                              : Icons.south_east_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          LoopCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              children: <Widget>[
                const MarketCandleChart(height: 210),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const LoopStatusPill(label: '4H', tone: LoopTone.market),
                    const SizedBox(width: 8),
                    Text(
                      '开发预览 K 线 · 非实时数据',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          context.push('/market/chart', extra: asset.symbol),
                      tooltip: 'Open full-screen chart',
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Market ledger'),
          LoopCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: LoopMetric(label: '24h volume', value: asset.volume),
                ),
                const Expanded(
                  child: LoopMetric(
                    label: 'Market cap',
                    value: '—',
                    detail: 'Provider missing',
                  ),
                ),
                const Expanded(
                  child: LoopMetric(
                    label: 'Liquidity',
                    value: '—',
                    detail: 'Provider missing',
                  ),
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Contract facts'),
          LoopCard(
            child: Column(
              children: const <Widget>[
                _SourcedFact(
                  title: 'Asset identity',
                  value: 'Core allowlist preview',
                  source: 'LOOP 开发预览 · 非实时数据',
                  tone: LoopTone.market,
                ),
                _SourcedFact(
                  title: 'Ownership controls',
                  value: '—',
                  source: 'Not checked · never treated as safe',
                  tone: LoopTone.warning,
                ),
                _SourcedFact(
                  title: 'Liquidity lock',
                  value: '—',
                  source: 'Provider result unavailable',
                  tone: LoopTone.neutral,
                  last: true,
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Community signal'),
          LoopCard(
            tone: LoopTone.conversation,
            accent: true,
            child: Row(
              children: <Widget>[
                const Icon(Icons.forum_outlined, color: LoopColors.chat),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Discussion preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No connected Stream conversation count. Community activity is unavailable.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Explore market structure'),
          Row(
            children: <Widget>[
              Expanded(
                child: _MarketDetailRoute(
                  icon: Icons.donut_large_rounded,
                  label: 'Holders',
                  onTap: () =>
                      context.push('/market/holders', extra: asset.symbol),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MarketDetailRoute(
                  icon: Icons.swap_vert_rounded,
                  label: 'Trades',
                  onTap: () =>
                      context.push('/market/trades', extra: asset.symbol),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/market/chart', extra: asset.symbol),
                  icon: const Icon(Icons.candlestick_chart_rounded),
                  label: const Text('Full chart'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: FilledButton(
                  onPressed: null,
                  child: Text('Buy unavailable'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MarketDetailRoute extends StatelessWidget {
  const _MarketDetailRoute({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SourcedFact extends StatelessWidget {
  const _SourcedFact({
    required this.title,
    required this.value,
    required this.source,
    required this.tone,
    this.last = false,
  });

  final String title;
  final String value;
  final String source;
  final LoopTone tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.circle, size: 7, color: loopToneColor(tone)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(source, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullChartScreen extends StatefulWidget {
  const FullChartScreen({
    super.key,
    this.symbol = 'ETH',
    this.snapshotState = MarketSnapshotState.preview,
  });

  final String symbol;
  final MarketSnapshotState snapshotState;

  @override
  State<FullChartScreen> createState() => _FullChartScreenState();
}

class _FullChartScreenState extends State<FullChartScreen> {
  String _period = '4H';
  String _indicator = 'MA';

  @override
  Widget build(BuildContext context) {
    final asset = MarketPreviewData.asset(widget.symbol);
    final hasFacts = widget.snapshotState == MarketSnapshotState.preview;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.close_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${asset.symbol} / USDC',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'C3 · chart preview',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: null,
            tooltip: 'Drawing tools are disabled in preview',
            icon: const Icon(Icons.draw_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: LoopColors.abyss),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MarketSnapshotBanner(
                  state: widget.snapshotState,
                  compact: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Text(
                      hasFacts ? asset.price : '—',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(width: 10),
                    if (hasFacts)
                      LoopStatusPill(
                        label: asset.change,
                        tone: asset.isPositive
                            ? LoopTone.positive
                            : LoopTone.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 43,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (final period in <String>[
                        '15M',
                        '1H',
                        '4H',
                        '1D',
                        '1W',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(period),
                            selected: period == _period,
                            onSelected: hasFacts
                                ? (_) => setState(() => _period = period)
                                : null,
                          ),
                        ),
                      const SizedBox(width: 7),
                      for (final indicator in <String>['MA', 'MACD', 'RSI'])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: FilterChip(
                            label: Text(indicator),
                            selected: indicator == _indicator,
                            onSelected: hasFacts
                                ? (_) => setState(() => _indicator = indicator)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: hasFacts
                      ? LoopCard(
                          padding: const EdgeInsets.fromLTRB(10, 18, 8, 8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return MarketCandleChart(
                                height: constraints.maxHeight,
                                semanticLabel:
                                    '${asset.symbol} $_period chart with $_indicator, simulated preview',
                              );
                            },
                          ),
                        )
                      : Center(
                          child: MarketStatePanel(state: widget.snapshotState),
                        ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Simulated candles · no live history · pinch, drawing, and execution disabled',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NewPairsScreen extends StatelessWidget {
  const NewPairsScreen({
    super.key,
    this.snapshotState = MarketSnapshotState.preview,
  });

  final MarketSnapshotState snapshotState;

  @override
  Widget build(BuildContext context) {
    final hasFacts = snapshotState == MarketSnapshotState.preview;
    return LoopPage(
      eyebrow: 'C10 · Discovery feed',
      title: 'New pairs',
      subtitle: 'A factual, source-labelled preview. High-risk and non-core candidates remain folded away.',
      children: <Widget>[
        MarketSnapshotBanner(state: snapshotState),
        const SizedBox(height: 16),
        const LoopStateCard(
          title: 'Core-only preview',
          message: 'This build shows BTC, ETH, and SOL pairs only. No score implies safety, and missing facts render as —.',
          icon: Icons.filter_alt_outlined,
          tone: LoopTone.market,
        ),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 16),
          MarketStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const LoopSectionLabel('Recently observed'),
          for (
            var index = 0;
            index < MarketPreviewData.coreAssets.length;
            index++
          ) ...<Widget>[
            _NewPairCard(
              asset: MarketPreviewData.coreAssets[index],
              age: const <String>['18 min', '42 min', '1 hr'][index],
              venue: const <String>[
                'Core spot',
                'Core spot',
                'Core spot',
              ][index],
              onTap: () => context.push(
                '/market/token',
                extra: MarketPreviewData.coreAssets[index].symbol,
              ),
            ),
            if (index != MarketPreviewData.coreAssets.length - 1)
              const SizedBox(height: 11),
          ],
          const LoopSectionLabel('Folded candidates'),
          const LoopStateCard(
            title: 'Non-core results hidden',
            message: '3 preview candidates are withheld because identity, liquidity, or ownership facts are unavailable.',
            icon: Icons.visibility_off_outlined,
            tone: LoopTone.warning,
          ),
        ],
      ],
    );
  }
}

class _NewPairCard extends StatelessWidget {
  const _NewPairCard({
    required this.asset,
    required this.age,
    required this.venue,
    required this.onTap,
  });

  final MarketAssetPreview asset;
  final String age;
  final String venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      onTap: onTap,
      semanticLabel: 'Open ${asset.symbol} pair facts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopAssetMark(symbol: asset.symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      asset.pair,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$venue · observed $age ago',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const LoopStatusPill(label: 'PREVIEW', tone: LoopTone.market),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          const Row(
            children: <Widget>[
              Expanded(
                child: LoopMetric(
                  label: 'Liquidity',
                  value: '—',
                  detail: 'Not connected',
                ),
              ),
              Expanded(
                child: LoopMetric(
                  label: 'Pool age',
                  value: '—',
                  detail: 'Preview only',
                ),
              ),
              Expanded(
                child: LoopMetric(
                  label: 'Ownership',
                  value: '—',
                  detail: 'Not checked',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
