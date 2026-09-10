import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

/// The Token Card's small line, driven by the real `1h` candle series.
///
/// It reads `GET /v2/market/assets/{assetId}/candles?interval=1h` through the
/// market port and draws the most recent [loopSparklineWindow] closes. There is
/// no other source: when the series is unavailable, empty or still loading, the
/// line is **not drawn at all** and the slot states the server's own reason
/// instead. A Token Card never shows a shape that is not a price.
class TokenCardSparkline extends ConsumerStatefulWidget {
  const TokenCardSparkline({
    required this.assetId,
    super.key,
    this.keyPrefix = 'token-card-sparkline',
    this.unavailableText,
  });

  final String assetId;

  /// The owning page's key prefix, so an assertion names that page.
  final String keyPrefix;

  /// Short copy for the not-drawn states, used by a page that already renders
  /// the same series' full reason elsewhere on screen. It must point at that
  /// block rather than restate it — the reason is still shown exactly once.
  final String? unavailableText;

  @override
  ConsumerState<TokenCardSparkline> createState() => _TokenCardSparklineState();
}

class _TokenCardSparklineState extends ConsumerState<TokenCardSparkline> {
  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetId,
      interval: LoopCandleInterval.oneHour,
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
    if (!state.isReady || block == null) {
      return _TokenCardChartNotice(
        blockKey: '${widget.keyPrefix}-unreadable',
        // A read that did not answer states what happened, not a reason code
        // the server never sent.
        text: state.phase == LoopChainViewPhase.loading
            ? '1H K 线读取中，读到之前不画任何走势。'
            : widget.unavailableText ??
                  loopChainFailureReason(state.failureKind),
      );
    }
    if (block is MarketCandlesUnavailable) {
      return _TokenCardChartNotice(
        blockKey: '${widget.keyPrefix}-unavailable',
        text: widget.unavailableText ?? loopReasonCodeText(block.reasonCode),
      );
    }
    final available = block as MarketCandlesAvailable;
    final closes = loopSparklineCloses(available.items);
    if (closes.isEmpty) {
      return _TokenCardChartNotice(
        blockKey: '${widget.keyPrefix}-empty',
        text: widget.unavailableText ?? '这个区间没有成交，只画有成交的桶，空桶不会补 0。',
      );
    }
    return LoopSparkline(
      key: ValueKey<String>('${widget.keyPrefix}-line'),
      closes: closes,
      semanticLabel:
          '${closes.length} 个 1H 收盘价的走势线，单位 ${available.priceUnit}，'
          '来源 ${loopFactSourceLabel(available.source)}',
    );
  }
}

/// The slot a Token Card renders instead of a line. It never draws a shape.
class _TokenCardChartNotice extends StatelessWidget {
  const _TokenCardChartNotice({required this.blockKey, required this.text});

  final String blockKey;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: ValueKey<String>(blockKey),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: LoopTypography.caption(11, color: LoopColors.muted),
      ),
    );
  }
}
