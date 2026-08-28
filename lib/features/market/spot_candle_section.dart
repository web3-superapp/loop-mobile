import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/market/spot_candle_chart.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Independent public-candle projection for an already resolved Spot market.
///
/// Candle failures never hide the accepted market snapshot above or the exact
/// public facts below this section. The component has no execution controls and
/// never falls back to preview candle fixtures.
class SpotCandleSection extends ConsumerWidget {
  const SpotCandleSection({
    required this.market,
    required this.interval,
    required this.onIntervalChanged,
    super.key,
    this.chartHeight = 220,
  });

  final HyperliquidSpotMarket market;
  final HyperliquidSpotCandleInterval interval;
  final ValueChanged<HyperliquidSpotCandleInterval> onIntervalChanged;
  final double chartHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = HyperliquidSpotCandleRequest(
      providerCoin: market.providerCoin,
      interval: interval,
    );
    final snapshot = ref.watch(hyperliquidSpotCandlesProvider(request));
    final isLoading = snapshot.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSectionLabel('Live K line · public history'),
        LoopCard(
          accent: true,
          tone: LoopTone.market,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '真实 K 线',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hyperliquid Testnet · candleSnapshot · 公共只读',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey<String>('refresh-live-spot-candles'),
                    onPressed: isLoading
                        ? null
                        : () => ref.invalidate(
                            hyperliquidSpotCandlesProvider(request),
                          ),
                    tooltip: '刷新当前周期真实 K 线',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final candidate in HyperliquidSpotCandleInterval.values)
                    ChoiceChip(
                      key: ValueKey<String>(
                        'spot-candle-period-${candidate.displayLabel}',
                      ),
                      label: Text(candidate.displayLabel),
                      selected: candidate == interval,
                      showCheckmark: false,
                      onSelected: isLoading
                          ? null
                          : (selected) {
                              if (selected && candidate != interval) {
                                onIntervalChanged(candidate);
                              }
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        snapshot.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => _SpotCandleLoading(interval: interval),
          error: (error, stackTrace) => LoopStateCard(
            title: 'K 线暂不可用',
            message: _candleFailureMessage(error),
            icon: Icons.candlestick_chart_outlined,
            tone: LoopTone.warning,
            action: _isRestrictedSessionFailure(error)
                ? null
                : OutlinedButton.icon(
                    key: const ValueKey<String>('retry-live-spot-candles'),
                    onPressed: () =>
                        ref.invalidate(hyperliquidSpotCandlesProvider(request)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试真实 K 线'),
                  ),
          ),
          data: (value) => value.candles.isEmpty
              ? LoopStateCard(
                  title: '这个时间窗口没有 K 线',
                  message:
                      'Testnet 没有返回 ${interval.displayLabel} 历史；未用演示 K 线或其他币种补齐。',
                  icon: Icons.hourglass_empty_rounded,
                  tone: LoopTone.neutral,
                  action: OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'retry-empty-live-spot-candles',
                    ),
                    onPressed: () =>
                        ref.invalidate(hyperliquidSpotCandlesProvider(request)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新请求'),
                  ),
                )
              : _SpotCandleDataCard(
                  market: market,
                  snapshot: value,
                  chartHeight: chartHeight,
                ),
        ),
      ],
    );
  }
}

class _SpotCandleLoading extends StatelessWidget {
  const _SpotCandleLoading({required this.interval});

  final HyperliquidSpotCandleInterval interval;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSkeletonView(presentation: LoopLoadingPresentation.chart()),
        const SizedBox(height: 12),
        Text(
          '正在加载 ${interval.displayLabel} 真实 K 线',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          '加载完成前不显示任何预览蜡烛。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _SpotCandleDataCard extends StatelessWidget {
  const _SpotCandleDataCard({
    required this.market,
    required this.snapshot,
    required this.chartHeight,
  });

  final HyperliquidSpotMarket market;
  final HyperliquidSpotCandleSnapshot snapshot;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final candles = snapshot.candles;
    final first = candles.first;
    final latest = candles.last;
    final highest = candles.reduce(
      (left, right) => left.high.value >= right.high.value ? left : right,
    );
    final lowest = candles.reduce(
      (left, right) => left.low.value <= right.low.value ? left : right,
    );
    final isForming = !snapshot.receivedAt.isAfter(latest.closeTime);

    return LoopCard(
      key: ValueKey<String>(
        'live-spot-candles-${snapshot.interval.displayLabel}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              LoopStatusPill(
                label: snapshot.interval.displayLabel,
                tone: LoopTone.market,
                icon: Icons.candlestick_chart_rounded,
              ),
              LoopStatusPill(
                label:
                    '${candles.length} candle${candles.length == 1 ? '' : 's'}',
                tone: LoopTone.neutral,
              ),
              LoopStatusPill(
                label: isForming ? '最后一根形成中' : '最后一根已收盘',
                tone: isForming ? LoopTone.warning : LoopTone.positive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SpotCandleChart(
            candles: candles,
            height: chartHeight,
            semanticLabel:
                '${market.pair} ${snapshot.interval.displayLabel} public Testnet candlestick chart, '
                '${candles.length} candles, exact low ${lowest.low.source}, '
                'exact high ${highest.high.source}, read only',
          ),
          const SizedBox(height: 14),
          Text(
            'Range ${lowest.low.source} – ${highest.high.source} ${market.quoteSymbol}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            'Latest O ${latest.open.source} · H ${latest.high.source} · '
            'L ${latest.low.source} · C ${latest.close.source} ${market.quoteSymbol}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'Volume ${latest.volume.source} ${market.baseSymbol} · '
            '${latest.tradeCount} trades',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Candle window ${_formatUtc(first.openTime)} → '
            '${_formatUtc(latest.closeTime)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Client received ${_formatUtc(snapshot.receivedAt)} · '
            '最多保留最近 120 根 · 不自动轮询',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (isForming) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              '最后一根在客户端收取时尚未结束，刷新后 OHLCV 可能变化。',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: loopToneColor(LoopTone.warning)),
            ),
          ],
        ],
      ),
    );
  }
}

bool _isRestrictedSessionFailure(Object error) {
  return error is HyperliquidMarketFailure &&
      error.kind == HyperliquidMarketFailureKind.restrictedSession;
}

String _candleFailureMessage(Object error) {
  if (error case HyperliquidMarketFailure(kind: final kind)) {
    return switch (kind) {
      HyperliquidMarketFailureKind.restrictedSession =>
        '受限会话保持离线，完成 Privy 验证后可加载 Testnet K 线。',
      HyperliquidMarketFailureKind.timeout => 'K 线请求超时，请检查网络后重试。',
      HyperliquidMarketFailureKind.connection => '无法连接 Testnet，请检查网络。',
      HyperliquidMarketFailureKind.unavailable => 'Testnet K 线服务暂时不可用。',
      HyperliquidMarketFailureKind.cancelled => 'K 线请求已取消。',
      HyperliquidMarketFailureKind.invalidPayload => 'K 线响应格式异常，已拒绝展示。',
      HyperliquidMarketFailureKind.unexpected => 'K 线加载失败，请稍后重试。',
    };
  }
  return 'K 线加载失败，请稍后重试。';
}

String _formatUtc(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')} UTC';
}
