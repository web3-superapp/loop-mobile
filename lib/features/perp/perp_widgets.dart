import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/perp/perp_models.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class PerpSnapshotBanner extends StatelessWidget {
  const PerpSnapshotBanner({
    required this.state,
    super.key,
    this.compact = false,
  });

  final PerpSnapshotState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final descriptor = switch (state) {
      PerpSnapshotState.preview => (
        'HYPERLIQUID PREVIEW · READ-ONLY',
        PerpPreviewData.observedLabel,
        LoopTone.positive,
        Icons.visibility_outlined,
      ),
      PerpSnapshotState.loading => (
        'LOADING CORRELATED SNAPSHOT',
        'Provider facts remain hidden',
        LoopTone.neutral,
        Icons.sync_rounded,
      ),
      PerpSnapshotState.offline => (
        'MARKET FEED OFFLINE',
        'Orders and stale PnL are disabled',
        LoopTone.warning,
        Icons.cloud_off_outlined,
      ),
      PerpSnapshotState.stale => (
        'SNAPSHOT EXPIRED · VALUES CLEARED',
        'Request a fresh provider snapshot',
        LoopTone.warning,
        Icons.history_toggle_off_rounded,
      ),
      PerpSnapshotState.empty => (
        'NO PROVIDER RECORDS',
        'No allowlisted Hyperliquid records returned',
        LoopTone.neutral,
        Icons.inbox_outlined,
      ),
      PerpSnapshotState.regionBlocked => (
        'REGION NOT ELIGIBLE',
        'Perpetual market data and actions are blocked',
        LoopTone.danger,
        Icons.public_off_outlined,
      ),
    };
    final color = loopToneColor(descriptor.$3);
    return Semantics(
      liveRegion: state != PerpSnapshotState.preview,
      label: '${descriptor.$1}. ${descriptor.$2}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 9 : 11,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.075),
          borderRadius: LoopRadius.small,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: <Widget>[
            Icon(descriptor.$4, size: 17, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    descriptor.$1,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: color, letterSpacing: 0.78),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      descriptor.$2,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
            if (state == PerpSnapshotState.preview)
              Text(
                'NO SUBMISSION',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }
}

class PerpStatePanel extends StatelessWidget {
  const PerpStatePanel({required this.state, super.key, this.onRetry});

  final PerpSnapshotState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == PerpSnapshotState.preview) return const SizedBox.shrink();
    if (state == PerpSnapshotState.loading) {
      return const _PerpLoadingPanel();
    }
    final descriptor = switch (state) {
      PerpSnapshotState.offline => (
        'Hyperliquid feed is offline',
        'LOOP cleared mark price, PnL, positions, and order controls until reconnection.',
        Icons.cloud_off_outlined,
        LoopTone.warning,
      ),
      PerpSnapshotState.stale => (
        'Provider snapshot expired',
        'Old values were removed rather than shown as current. Request a fresh snapshot to continue.',
        Icons.history_toggle_off_rounded,
        LoopTone.warning,
      ),
      PerpSnapshotState.empty => (
        'No Hyperliquid records',
        'This preview returned no positions, orders, fills, or allowlisted markets for the selected view.',
        Icons.inbox_outlined,
        LoopTone.neutral,
      ),
      PerpSnapshotState.regionBlocked => (
        'Perpetuals unavailable here',
        'Regional eligibility could not be confirmed. LOOP blocks provider facts and all trading actions.',
        Icons.public_off_outlined,
        LoopTone.danger,
      ),
      _ => throw StateError('State is handled before the switch.'),
    };
    return LoopStateCard(
      title: descriptor.$1,
      message: descriptor.$2,
      icon: descriptor.$3,
      tone: descriptor.$4,
      action: onRetry != null && state != PerpSnapshotState.regionBlocked
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry preview'),
            )
          : null,
    );
  }
}

class _PerpLoadingPanel extends StatelessWidget {
  const _PerpLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading Hyperliquid preview',
      child: LoopCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Correlating provider snapshot',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              'Prices, PnL, and order controls appear only after schema, request identity, and freshness checks pass.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class PerpModeControl extends StatelessWidget {
  const PerpModeControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              onPressed: () => context.go('/market'),
              icon: const Icon(Icons.currency_exchange_rounded, size: 18),
              label: const Text('Spot'),
              style: TextButton.styleFrom(
                foregroundColor: LoopColors.vapor,
                minimumSize: const Size(48, 44),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LoopColors.mint.withValues(alpha: 0.11),
                borderRadius: LoopRadius.small,
                border: Border.all(
                  color: LoopColors.mint.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Perpetual',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: LoopColors.mint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PerpQuickRoutes extends StatelessWidget {
  const PerpQuickRoutes({super.key});

  @override
  Widget build(BuildContext context) {
    const routes = <(String, String, IconData)>[
      ('Positions', '/perp/positions', Icons.layers_outlined),
      ('Orders', '/perp/orders', Icons.list_alt_rounded),
      ('History', '/perp/history', Icons.history_rounded),
      ('Account', '/perp/account', Icons.account_balance_wallet_outlined),
    ];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: routes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final route = routes[index];
          return SizedBox(
            width: 92,
            child: OutlinedButton(
              onPressed: () => context.push(route.$2),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(route.$3, size: 19),
                  const SizedBox(height: 7),
                  Text(
                    route.$1,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PerpMarketRow extends StatelessWidget {
  const PerpMarketRow({required this.market, required this.onTap, super.key});

  final PerpMarketPreview market;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      onTap: onTap,
      semanticLabel: 'Open ${market.symbol} perpetual preview',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopAssetMark(symbol: market.symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${market.symbol}-PERP',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hyperliquid Core',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(market.markPrice, style: context.dataStyle),
                  const SizedBox(height: 4),
                  Text(
                    market.change,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: market.isPositive
                          ? LoopColors.mint
                          : LoopColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: <Widget>[
              Expanded(
                child: LoopMetric(label: 'Funding / 8h', value: market.funding),
              ),
              Expanded(
                child: LoopMetric(
                  label: 'Open interest',
                  value: market.openInterest,
                ),
              ),
              Expanded(
                child: LoopMetric(label: '24h volume', value: market.volume),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PerpReadOnlyNotice extends StatelessWidget {
  const PerpReadOnlyNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: 'Execution locked',
      message: message ?? 'Production credentials, regional eligibility, and Privy signing are not connected. This route cannot submit.',
      icon: Icons.lock_outline_rounded,
      tone: LoopTone.warning,
    );
  }
}

/// Retained Perp history: the fixed preview candlestick sketch that used to
/// live in the Market slice. It carries no provider data and is not mounted in
/// product navigation.
class MarketCandleChart extends StatelessWidget {
  const MarketCandleChart({
    super.key,
    this.height = 220,
    this.showAxis = true,
    this.semanticLabel = 'Simulated candlestick chart, read-only preview',
  });

  final double height;
  final bool showAxis;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _CandlePainter(
            candles: CandlePreviewData.candles,
            showAxis: showAxis,
          ),
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter({required this.candles, required this.showAxis});

  final List<CandlePreview> candles;
  final bool showAxis;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final plotRight = showAxis ? size.width - 45 : size.width;
    final gridPaint = Paint()
      ..color = LoopColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(plotRight, y),
        gridPaint,
      );
    }
    for (var index = 0; index <= 5; index++) {
      final x = plotRight * index / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final low = candles.map((candle) => candle.low).reduce(math.min);
    final high = candles.map((candle) => candle.high).reduce(math.max);
    final span = math.max(high - low, 1);
    double yFor(double value) =>
        size.height - ((value - low) / span * (size.height - 16)) - 8;

    final slot = plotRight / candles.length;
    final bodyWidth = math.max(3.0, slot * 0.48);
    for (var index = 0; index < candles.length; index++) {
      final candle = candles[index];
      final color = candle.isUp ? LoopColors.mint : LoopColors.danger;
      final x = slot * index + slot / 2;
      canvas.drawLine(
        Offset(x, yFor(candle.high)),
        Offset(x, yFor(candle.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.25,
      );
      final top = math.min(yFor(candle.open), yFor(candle.close));
      final bottom = math.max(yFor(candle.open), yFor(candle.close));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - bodyWidth / 2,
            top,
            x + bodyWidth / 2,
            math.max(bottom, top + 2),
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }

    if (showAxis) {
      final painter = TextPainter(textDirection: TextDirection.ltr);
      for (var index = 0; index <= 4; index++) {
        final value = high - ((high - low) * index / 4);
        painter.text = TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(
            color: LoopColors.vapor,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        );
        painter.layout();
        painter.paint(
          canvas,
          Offset(plotRight + 7, size.height * index / 4 - 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.showAxis != showAxis;
  }
}

/// Retained Perp history: the fixed candle sketch the preview chart draws.
/// It is not market data and never reaches a product surface.
final class CandlePreview {
  const CandlePreview({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;

  bool get isUp => close >= open;
}

abstract final class CandlePreviewData {
  static const List<CandlePreview> candles = <CandlePreview>[
    CandlePreview(open: 42, high: 51, low: 39, close: 48),
    CandlePreview(open: 48, high: 54, low: 44, close: 46),
    CandlePreview(open: 46, high: 58, low: 45, close: 56),
    CandlePreview(open: 56, high: 61, low: 51, close: 53),
    CandlePreview(open: 53, high: 65, low: 52, close: 62),
    CandlePreview(open: 62, high: 68, low: 57, close: 59),
    CandlePreview(open: 59, high: 73, low: 58, close: 70),
    CandlePreview(open: 70, high: 76, low: 64, close: 67),
    CandlePreview(open: 67, high: 80, low: 66, close: 77),
    CandlePreview(open: 77, high: 82, low: 69, close: 72),
    CandlePreview(open: 72, high: 86, low: 71, close: 83),
    CandlePreview(open: 83, high: 89, low: 77, close: 80),
    CandlePreview(open: 80, high: 93, low: 78, close: 90),
    CandlePreview(open: 90, high: 96, low: 84, close: 87),
    CandlePreview(open: 87, high: 99, low: 86, close: 96),
    CandlePreview(open: 96, high: 101, low: 89, close: 92),
    CandlePreview(open: 92, high: 105, low: 91, close: 102),
    CandlePreview(open: 102, high: 108, low: 96, close: 104),
  ];
}
