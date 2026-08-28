import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/navigation/spot_market_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/spot_candle_section.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  static const _resultLimit = 50;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(hyperliquidSpotMarketsProvider);
    final isPreview = ref.watch(
      loopSessionProvider.select((session) => session.isPreview),
    );
    return LoopPage(
      eyebrow: 'C1 · Hyperliquid Testnet · Spot',
      title: 'Spot market',
      subtitle: '公共现货行情只读。余额、下单、撤单与签名不经过这条移动端数据路径。',
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('refresh-live-spot-markets'),
          onPressed: snapshot.isLoading
              ? null
              : () => ref.invalidate(hyperliquidSpotMarketsProvider),
          tooltip: '刷新 Hyperliquid Testnet 现货行情',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        const Align(
          alignment: Alignment.centerLeft,
          child: LoopContextRail(stage: LoopStage.discover),
        ),
        const SizedBox(height: 14),
        const _SpotMarketBanner(),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey<String>('live-spot-market-search'),
          controller: _searchController,
          onChanged: (value) {
            setState(() => _query = value.trim().toUpperCase());
          },
          decoration: InputDecoration(
            hintText: '搜索现货，例如 HYPE 或 USDC',
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
        if (isPreview) const _MarketPreviewQuickActions(),
        ...snapshot.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => const <Widget>[
            SizedBox(height: 20),
            _SpotMarketLoading(),
          ],
          error: (error, stackTrace) => <Widget>[
            const SizedBox(height: 20),
            _SpotMarketError(
              message: _marketFailureMessage(error),
              onRetry: _isRestrictedSessionFailure(error) ? null : _retry,
            ),
          ],
          data: (value) {
            final sorted = value.markets.toList(growable: false)
              ..sort(
                (left, right) => right.dayNotionalVolume.value.compareTo(
                  left.dayNotionalVolume.value,
                ),
              );
            final matches = sorted
                .where((market) {
                  if (_query.isEmpty) return market.hasDayActivity;
                  final searchable = <String>[
                    market.baseSymbol,
                    market.quoteSymbol,
                    market.pair,
                    market.providerCoin,
                    market.spotIndex.toString(),
                  ].join(' ').toUpperCase();
                  return searchable.contains(_query);
                })
                .toList(growable: false);
            final visible = matches.take(_resultLimit).toList(growable: false);
            if (visible.isEmpty) {
              return <Widget>[
                const SizedBox(height: 20),
                _SpotMarketEmpty(hasQuery: _query.isNotEmpty),
              ];
            }
            return <Widget>[
              LoopSectionLabel('Live spot markets · ${visible.length}'),
              _SpotMarketLedgerHeader(
                snapshot: value,
                shown: visible.length,
                matched: matches.length,
              ),
              const SizedBox(height: 10),
              for (final (index, market) in visible.indexed) ...<Widget>[
                _SpotMarketRow(
                  rank: index + 1,
                  market: market,
                  onTap: () =>
                      context.push(SpotMarketRoute.location(market.spotIndex)),
                ),
                if (index != visible.length - 1) const SizedBox(height: 10),
              ],
            ];
          },
        ),
      ],
    );
  }

  void _retry() => ref.invalidate(hyperliquidSpotMarketsProvider);
}

class _MarketPreviewQuickActions extends StatelessWidget {
  const _MarketPreviewQuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('market-preview-quick-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 15),
        const LoopSectionLabel('Frontend previews'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                <(String, String, Key?)>[
                      ('Watchlist · 开发预览', '/market/watchlist', null),
                      (
                        'New · 开发预览',
                        '/market/new',
                        const ValueKey<String>(
                          'market-new-pairs-preview-entry',
                        ),
                      ),
                      ('Smart money · 开发预览', '/market/smart-money', null),
                    ]
                    .map(
                      (destination) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          key: destination.$3,
                          label: Text(destination.$1),
                          onPressed: () => context.push(destination.$2),
                        ),
                      ),
                    )
                    .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SpotMarketBanner extends StatelessWidget {
  const _SpotMarketBanner();

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.market,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.currency_exchange_rounded, color: LoopColors.market),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TESTNET · SPOT · 实时公共数据 · 只读',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: LoopColors.market, letterSpacing: 0.85),
                ),
                const SizedBox(height: 5),
                Text(
                  '价格与 24h 成交量由 Hyperliquid 字符串精确解析；当前没有余额、报价或买卖能力。',
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

class _SpotMarketLoading extends StatelessWidget {
  const _SpotMarketLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '正在加载 Hyperliquid Testnet 现货行情',
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

class _SpotMarketError extends StatelessWidget {
  const _SpotMarketError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: '现货行情暂不可用',
      message: message,
      icon: Icons.cloud_off_outlined,
      tone: LoopTone.danger,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              key: const ValueKey<String>('retry-live-spot-markets'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
    );
  }
}

class _SpotMarketEmpty extends StatelessWidget {
  const _SpotMarketEmpty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: hasQuery ? '没有匹配的现货市场' : '暂无活跃现货市场',
      message: hasQuery
          ? '尝试输入其他代币、交易对或 Spot index。'
          : 'Testnet 当前没有返回 24h 成交活动，请稍后刷新。',
      icon: hasQuery ? Icons.search_off_rounded : Icons.inbox_outlined,
      tone: LoopTone.neutral,
    );
  }
}

class _SpotMarketLedgerHeader extends StatelessWidget {
  const _SpotMarketLedgerHeader({
    required this.snapshot,
    required this.shown,
    required this.matched,
  });

  final HyperliquidSpotSnapshot snapshot;
  final int shown;
  final int matched;

  @override
  Widget build(BuildContext context) {
    final received = snapshot.receivedAt;
    final receivedLabel = <int>[
      received.hour,
      received.minute,
      received.second,
    ].map((value) => value.toString().padLeft(2, '0')).join(':');
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$shown / $matched · client received $receivedLabel UTC',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Text(
          'MARK / 24H',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class _SpotMarketRow extends StatelessWidget {
  const _SpotMarketRow({
    required this.rank,
    required this.market,
    required this.onTap,
  });

  final int rank;
  final HyperliquidSpotMarket market;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = market.dayChangePercent;
    final changeIsNegative = change != null && change < Decimal.zero;
    final changeLabel = change == null
        ? '24h —'
        : '${changeIsNegative ? '' : '+'}${change.toStringAsFixed(2)}%';
    final changeColor = change == null
        ? LoopColors.vapor
        : changeIsNegative
        ? LoopColors.danger
        : LoopColors.mint;

    return LoopCard(
      key: ValueKey<String>('spot-market-${market.spotIndex}'),
      onTap: onTap,
      semanticLabel:
          '${market.pair}, mark ${market.markPrice.source} ${market.quoteSymbol}, $changeLabel, 打开详情',
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
          LoopAssetMark(symbol: market.baseSymbol),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  market.pair,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'Hyperliquid Testnet · spot #${market.spotIndex}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '24h ${_groupIntegerPart(market.dayNotionalVolume.source)} ${market.quoteSymbol}',
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
                  '${_groupIntegerPart(market.markPrice.source)} ${market.quoteSymbol}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dataStyle,
                ),
                const SizedBox(height: 5),
                Text(
                  changeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: LoopColors.vapor,
          ),
        ],
      ),
    );
  }
}

/// Public, read-only detail projection for one Hyperliquid Testnet spot pair.
///
/// The route resolves the pair from the same accepted `spotMetaAndAssetCtxs`
/// snapshot as the primary ledger. It deliberately exposes no account,
/// execution, signing, or provider-history capability.
class SpotMarketDetailScreen extends ConsumerStatefulWidget {
  const SpotMarketDetailScreen({required this.spotIndex, super.key});

  final int? spotIndex;

  @override
  ConsumerState<SpotMarketDetailScreen> createState() =>
      _SpotMarketDetailScreenState();
}

class _SpotMarketDetailScreenState
    extends ConsumerState<SpotMarketDetailScreen> {
  HyperliquidSpotCandleInterval _interval =
      HyperliquidSpotCandleInterval.fourHours;

  @override
  Widget build(BuildContext context) {
    final resolvedSpotIndex = widget.spotIndex;
    if (resolvedSpotIndex == null || resolvedSpotIndex < 0) {
      return const LoopPage(
        eyebrow: 'C2 · Hyperliquid Testnet · Spot',
        title: 'Invalid spot market',
        subtitle: 'Spot 详情必须使用有效的非负 provider index。',
        children: <Widget>[
          LoopStateCard(
            title: '无法打开这个现货市场',
            message: '路由中的 Spot index 无效，未加载行情或回退到演示币种。',
            icon: Icons.link_off_rounded,
            tone: LoopTone.neutral,
          ),
        ],
      );
    }
    final snapshot = ref.watch(hyperliquidSpotMarketsProvider);
    return snapshot.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      loading: () => const LoopPage(
        eyebrow: 'C2 · Hyperliquid Testnet · Spot',
        title: 'Spot market detail',
        subtitle: '正在读取公共现货发现数据。',
        children: <Widget>[_SpotMarketLoading()],
      ),
      error: (error, stackTrace) => LoopPage(
        eyebrow: 'C2 · Hyperliquid Testnet · Spot',
        title: 'Spot market detail',
        subtitle: '公共现货详情保持只读，不会回退到演示价格或永续行情。',
        children: <Widget>[
          _SpotMarketError(
            message: _marketFailureMessage(error),
            onRetry: _isRestrictedSessionFailure(error)
                ? null
                : () => ref.invalidate(hyperliquidSpotMarketsProvider),
          ),
        ],
      ),
      data: (value) {
        final market = _findSpotMarket(value.markets, resolvedSpotIndex);
        if (market == null) {
          return LoopPage(
            eyebrow: 'C2 · Hyperliquid Testnet · Spot #$resolvedSpotIndex',
            title: 'Spot market unavailable',
            subtitle: '这次公共响应中没有该 Spot index，未使用其他币种或演示数据替代。',
            actions: <Widget>[
              IconButton(
                key: const ValueKey<String>('refresh-spot-market-detail'),
                onPressed: () => ref.invalidate(hyperliquidSpotMarketsProvider),
                tooltip: '刷新 Hyperliquid Testnet 现货详情',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            children: const <Widget>[
              LoopStateCard(
                title: '找不到这个现货市场',
                message: '它可能暂时未被 Testnet 返回，请刷新后重试。',
                icon: Icons.search_off_rounded,
                tone: LoopTone.neutral,
              ),
            ],
          );
        }
        return _SpotMarketDetailContent(
          market: market,
          receivedAt: value.receivedAt,
          interval: _interval,
          onIntervalChanged: (value) => setState(() => _interval = value),
          onRefresh: () {
            ref.invalidate(
              hyperliquidSpotCandlesProvider(
                HyperliquidSpotCandleRequest(
                  providerCoin: market.providerCoin,
                  interval: _interval,
                ),
              ),
            );
            ref.invalidate(hyperliquidSpotMarketsProvider);
          },
        );
      },
    );
  }
}

HyperliquidSpotMarket? _findSpotMarket(
  List<HyperliquidSpotMarket> markets,
  int spotIndex,
) {
  for (final market in markets) {
    if (market.spotIndex == spotIndex) return market;
  }
  return null;
}

class _SpotMarketDetailContent extends StatelessWidget {
  const _SpotMarketDetailContent({
    required this.market,
    required this.receivedAt,
    required this.interval,
    required this.onIntervalChanged,
    required this.onRefresh,
  });

  final HyperliquidSpotMarket market;
  final DateTime receivedAt;
  final HyperliquidSpotCandleInterval interval;
  final ValueChanged<HyperliquidSpotCandleInterval> onIntervalChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final change = market.dayChangePercent;
    final changeIsNegative = change != null && change < Decimal.zero;
    final changeLabel = change == null
        ? '24h change unavailable'
        : '${changeIsNegative ? '' : '+'}${change.toStringAsFixed(2)}% · 24h';
    final changeTone = change == null
        ? LoopTone.neutral
        : changeIsNegative
        ? LoopTone.danger
        : LoopTone.positive;

    return LoopPage(
      key: ValueKey<String>('spot-market-detail-${market.spotIndex}'),
      eyebrow: 'C2 · Hyperliquid Testnet · Spot #${market.spotIndex}',
      title: market.pair,
      subtitle: '公共现货发现详情，只读且不是可执行报价。余额、买卖、签名与订单仍不可用。',
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('refresh-spot-market-detail'),
          onPressed: onRefresh,
          tooltip: '刷新 Hyperliquid Testnet 现货详情',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        const _SpotMarketBanner(),
        const SizedBox(height: 18),
        LoopCard(
          accent: true,
          tone: LoopTone.market,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoopAssetMark(symbol: market.baseSymbol, size: 52),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_groupIntegerPart(market.markPrice.source)} ${market.quoteSymbol}',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    _SpotChangeBadge(
                      label: changeLabel,
                      tone: changeTone,
                      icon: change == null
                          ? Icons.remove_rounded
                          : changeIsNegative
                          ? Icons.south_east_rounded
                          : Icons.north_east_rounded,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Public mark · not an executable quote',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SpotCandleSection(
          market: market,
          interval: interval,
          onIntervalChanged: onIntervalChanged,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: ValueKey<String>('open-full-spot-chart-${market.spotIndex}'),
          onPressed: () =>
              context.push(SpotMarketRoute.chartLocation(market.spotIndex)),
          icon: const Icon(Icons.open_in_full_rounded),
          label: const Text('打开真实全屏 K 线'),
        ),
        const LoopSectionLabel('Public market facts'),
        LoopCard(
          child: Column(
            children: <Widget>[
              _SpotDetailFact(
                label: 'Mark price',
                value: '${market.markPrice.source} ${market.quoteSymbol}',
                detail: 'Exact public wire value',
              ),
              _SpotDetailFact(
                label: 'Mid price',
                value: market.midPrice == null
                    ? '—'
                    : '${market.midPrice!.source} ${market.quoteSymbol}',
                detail: market.midPrice == null
                    ? 'Not present in this response'
                    : 'Exact public wire value',
              ),
              _SpotDetailFact(
                label: 'Previous-day price',
                value:
                    '${market.previousDayPrice.source} ${market.quoteSymbol}',
                detail: 'Provider comparison input',
              ),
              _SpotDetailFact(
                label: '24h notional volume',
                value:
                    '${market.dayNotionalVolume.source} ${market.quoteSymbol}',
                detail: 'Exact public wire value',
              ),
              _SpotDetailFact(
                label: '24h base volume',
                value: '${market.dayBaseVolume.source} ${market.baseSymbol}',
                detail: 'Exact public wire value',
                last: true,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Provider identity'),
        LoopCard(
          child: Column(
            children: <Widget>[
              _SpotDetailFact(
                label: 'Provider coin',
                value: market.providerCoin,
                detail: 'Hyperliquid protocol identifier',
              ),
              _SpotDetailFact(
                label: 'Spot index',
                value: market.spotIndex.toString(),
                detail: 'Hyperliquid Testnet',
              ),
              _SpotDetailFact(
                label: 'Base token',
                value: '${market.baseSymbol} · index ${market.baseTokenIndex}',
                detail: market.baseTokenId,
              ),
              _SpotDetailFact(
                label: 'Quote token',
                value:
                    '${market.quoteSymbol} · index ${market.quoteTokenIndex}',
                detail: market.quoteTokenId,
              ),
              _SpotDetailFact(
                label: 'Base size decimals',
                value: market.baseSizeDecimals.toString(),
                detail: market.isCanonical
                    ? 'Canonical spot universe entry'
                    : 'Non-canonical spot universe entry',
                last: true,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Freshness and coverage'),
        LoopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                HyperliquidSpotSnapshot.sourceLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Client received ${_formatSpotReceivedAt(receivedAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '这是客户端收到完整响应的时间，不是交易所快照、成交或区块时间。',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpotChangeBadge extends StatelessWidget {
  const _SpotChangeBadge({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final LoopTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(tone);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: LoopRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Wrap(
            spacing: 5,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 14),
              Text(
                label,
                softWrap: true,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotDetailFact extends StatelessWidget {
  const _SpotDetailFact({
    required this.label,
    required this.value,
    required this.detail,
    this.last = false,
  });

  final String label;
  final String value;
  final String detail;
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
          Expanded(
            flex: 4,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSpotReceivedAt(DateTime value) {
  final utc = value.toUtc();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}-${twoDigits(utc.month)}-${twoDigits(utc.day)} '
      '${twoDigits(utc.hour)}:${twoDigits(utc.minute)}:${twoDigits(utc.second)} UTC';
}

/// Retained only as read-only regression coverage for the former Testnet feed.
///
/// Product navigation does not mount this screen while LOOP is spot-only.
class LegacyPerpetualMarketScreen extends ConsumerStatefulWidget {
  const LegacyPerpetualMarketScreen({super.key});

  @override
  ConsumerState<LegacyPerpetualMarketScreen> createState() =>
      _LegacyPerpetualMarketScreenState();
}

class _LegacyPerpetualMarketScreenState
    extends ConsumerState<LegacyPerpetualMarketScreen> {
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
                      ? () => context.go('/market')
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

/// C3 full-screen projection of one admitted public Testnet Spot market.
///
/// Route identity is the provider's exact non-negative Spot index. Market
/// admission always precedes the candle request, so malformed or stale links
/// cannot substitute ETH, another market, Preview fixtures, or Perp data.
class FullChartScreen extends ConsumerStatefulWidget {
  const FullChartScreen({required this.spotIndex, super.key});

  final int? spotIndex;

  @override
  ConsumerState<FullChartScreen> createState() => _FullChartScreenState();
}

class _FullChartScreenState extends ConsumerState<FullChartScreen> {
  HyperliquidSpotCandleInterval _interval =
      HyperliquidSpotCandleInterval.fourHours;

  @override
  Widget build(BuildContext context) {
    final resolvedSpotIndex = widget.spotIndex;
    if (resolvedSpotIndex == null || resolvedSpotIndex < 0) {
      return const _SpotFullChartFrame(
        title: 'Invalid spot chart',
        subtitle: 'C3 · Hyperliquid Testnet · Spot',
        children: <Widget>[
          LoopStateCard(
            title: '无法打开这张全屏 K 线',
            message: '路由必须只携带一个规范的非负 spotIndex。未请求行情、K 线或演示币种。',
            icon: Icons.link_off_rounded,
            tone: LoopTone.neutral,
          ),
        ],
      );
    }

    final snapshot = ref.watch(hyperliquidSpotMarketsProvider);
    return snapshot.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      loading: () => const _SpotFullChartFrame(
        title: 'Spot chart',
        subtitle: 'C3 · Hyperliquid Testnet · Spot',
        children: <Widget>[
          LoopSkeletonView(presentation: LoopLoadingPresentation.chart()),
          SizedBox(height: 12),
          Text('正在用路由中的精确 spotIndex 解析公共现货市场。', textAlign: TextAlign.center),
        ],
      ),
      error: (error, stackTrace) => _SpotFullChartFrame(
        title: 'Spot chart unavailable',
        subtitle: 'C3 · Hyperliquid Testnet · Spot #$resolvedSpotIndex',
        children: <Widget>[
          LoopStateCard(
            title: '无法确认这个现货市场',
            message: _marketFailureMessage(error),
            icon: Icons.candlestick_chart_outlined,
            tone: LoopTone.warning,
            action: _isRestrictedSessionFailure(error)
                ? null
                : OutlinedButton.icon(
                    key: const ValueKey<String>('retry-full-spot-chart-market'),
                    onPressed: () =>
                        ref.invalidate(hyperliquidSpotMarketsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试公共现货市场'),
                  ),
          ),
        ],
      ),
      data: (value) {
        final market = _findSpotMarket(value.markets, resolvedSpotIndex);
        if (market == null) {
          return _SpotFullChartFrame(
            title: 'Spot chart unavailable',
            subtitle: 'C3 · Hyperliquid Testnet · Spot #$resolvedSpotIndex',
            children: <Widget>[
              LoopStateCard(
                title: '找不到这个现货市场',
                message: '当前公共响应未接纳该 spotIndex，未请求 K 线，也未回退到其他币种。',
                icon: Icons.search_off_rounded,
                tone: LoopTone.neutral,
                action: OutlinedButton.icon(
                  key: const ValueKey<String>('refresh-missing-spot-chart'),
                  onPressed: () =>
                      ref.invalidate(hyperliquidSpotMarketsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新市场'),
                ),
              ),
            ],
          );
        }
        return _SpotFullChartData(
          market: market,
          marketReceivedAt: value.receivedAt,
          interval: _interval,
          onIntervalChanged: (value) => setState(() => _interval = value),
        );
      },
    );
  }
}

class _SpotFullChartData extends StatelessWidget {
  const _SpotFullChartData({
    required this.market,
    required this.marketReceivedAt,
    required this.interval,
    required this.onIntervalChanged,
  });

  final HyperliquidSpotMarket market;
  final DateTime marketReceivedAt;
  final HyperliquidSpotCandleInterval interval;
  final ValueChanged<HyperliquidSpotCandleInterval> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final change = market.dayChangePercent;
    final changeIsNegative = change != null && change < Decimal.zero;
    final chartHeight =
        MediaQuery.orientationOf(context) == Orientation.landscape
        ? 240.0
        : 340.0;

    return _SpotFullChartFrame(
      key: ValueKey<String>('full-spot-chart-${market.spotIndex}'),
      title: market.pair,
      subtitle: 'C3 · Hyperliquid Testnet · Spot #${market.spotIndex}',
      children: <Widget>[
        const _SpotMarketBanner(),
        const SizedBox(height: 14),
        LoopCard(
          accent: true,
          tone: LoopTone.market,
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              LoopAssetMark(symbol: market.baseSymbol, size: 46),
              Text(
                '${_groupIntegerPart(market.markPrice.source)} ${market.quoteSymbol}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              _SpotChangeBadge(
                label: change == null
                    ? '24h change unavailable'
                    : '${changeIsNegative ? '' : '+'}${change.toStringAsFixed(2)}% · 24h',
                tone: change == null
                    ? LoopTone.neutral
                    : changeIsNegative
                    ? LoopTone.danger
                    : LoopTone.positive,
                icon: change == null
                    ? Icons.remove_rounded
                    : changeIsNegative
                    ? Icons.south_east_rounded
                    : Icons.north_east_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SpotCandleSection(
          market: market,
          interval: interval,
          onIntervalChanged: onIntervalChanged,
          chartHeight: chartHeight,
        ),
        const SizedBox(height: 12),
        LoopStateCard(
          title: '公共只读图表',
          message:
              'Market 快照由客户端于 ${_formatSpotReceivedAt(marketReceivedAt)} 收取。画线、计算指标、余额与买卖均未开放。',
          icon: Icons.visibility_outlined,
          tone: LoopTone.market,
        ),
      ],
    );
  }
}

class _SpotFullChartFrame extends StatelessWidget {
  const _SpotFullChartFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/market');
            }
          },
          tooltip: '关闭全屏 K 线',
          icon: const Icon(Icons.close_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: LoopColors.abyss),
          child: ListView(
            key: const ValueKey<String>('full-spot-chart-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: children,
          ),
        ),
      ),
    );
  }
}

class NewPairsScreen extends ConsumerWidget {
  const NewPairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(
      loopSessionProvider.select((session) => session.isPreview),
    );
    return isPreview
        ? const _NewPairsPreviewScreen()
        : const _NewPairsUnavailableScreen();
  }
}

class _NewPairsUnavailableScreen extends StatelessWidget {
  const _NewPairsUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      key: const ValueKey<String>('market-new-pairs-production-unavailable'),
      eyebrow: 'C10 · Data source required',
      title: 'New pairs',
      subtitle: 'New-pair discovery needs an attributable listing-time source. The public Spot snapshot cannot prove when a pair was listed.',
      children: <Widget>[
        const LoopStateCard(
          title: 'New pairs not connected',
          message: 'No listing-time source is connected. Price, client receipt time, first local observation, volume, and canonical status do not prove that a pair is new.',
          icon: Icons.link_off_rounded,
          tone: LoopTone.neutral,
        ),
        const SizedBox(height: 16),
        Align(
          key: const ValueKey<String>(
            'market-new-pairs-production-content-end',
          ),
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/market'),
            icon: const Icon(Icons.show_chart_rounded),
            label: const Text('Open public Spot market'),
          ),
        ),
      ],
    );
  }
}

class _NewPairsPreviewScreen extends StatelessWidget {
  const _NewPairsPreviewScreen();

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      key: const ValueKey<String>('market-new-pairs-preview-fixtures'),
      eyebrow: 'C10 · 开发预览 · Discovery feed',
      title: 'New pairs',
      subtitle: 'A labelled fictional preview. It does not establish listing time, liquidity, ownership, or safety.',
      children: <Widget>[
        const MarketSnapshotBanner(state: MarketSnapshotState.preview),
        const SizedBox(height: 16),
        const LoopStateCard(
          title: 'Sample-only preview',
          message: 'This build shows BTC, ETH, and SOL pairs only. No score implies safety, and missing facts render as —.',
          icon: Icons.filter_alt_outlined,
          tone: LoopTone.market,
        ),
        const LoopSectionLabel('Recently observed · 演示数据'),
        for (
          var index = 0;
          index < MarketPreviewData.coreAssets.length;
          index++
        ) ...<Widget>[
          _NewPairCard(
            asset: MarketPreviewData.coreAssets[index],
            age: const <String>['18 min', '42 min', '1 hr'][index],
            venue: const <String>[
              'Spot preview',
              'Spot preview',
              'Spot preview',
            ][index],
            onTap: () => context.go('/market'),
          ),
          if (index != MarketPreviewData.coreAssets.length - 1)
            const SizedBox(height: 11),
        ],
        const LoopSectionLabel('Folded candidates · 演示数据'),
        const LoopStateCard(
          key: ValueKey<String>('market-new-pairs-preview-content-end'),
          title: 'Non-core results hidden',
          message: '3 preview candidates are withheld because identity, liquidity, or ownership facts are unavailable.',
          icon: Icons.visibility_off_outlined,
          tone: LoopTone.warning,
        ),
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
      semanticLabel:
          'Open live Spot market after reviewing ${asset.symbol} preview',
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
                      '$venue · Fixture age · $age',
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

// End of the C10 Preview source boundary reviewed by the repository Harness.
