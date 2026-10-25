import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

// ---------------------------------------------------------------------------
// 情报 · 行情 rows (decision 0118)
// ---------------------------------------------------------------------------
//
// The reference the requester approved (Fomo, 2026-10-08) reads a price list
// as one continuous table: a 36pt mark, the ticker over its market cap, and
// the price over its 24-hour move, with nothing but a hairline between rows.
// The 58pt row with a sparkline column and a solid change block stays for
// the surfaces that still use it; this is the list's own row.

/// The one height every 情报 · 行情 row takes.
const double marketFomoRowHeight = loopQuoteRowHeight;

/// The mark at the head of a row.
const double marketFomoLogoSize = 36;

/// The width the price column may give to a row that has no price.
const double marketFomoUnavailableWidth = 168;

/// 「▲ 2.50%」 / 「▼ 1.01%」 / 「0.00%」: a 24-hour move in percent points.
///
/// The triangle carries the direction for a reader who does not see colour;
/// the sign is dropped because the triangle already states it. Zero has no
/// direction and no triangle.
String marketMoveLabel(Decimal percent) {
  final move = LoopPriceMove.of(percent);
  final magnitude = percent < Decimal.zero ? -percent : percent;
  final figure = '${magnitude.toStringAsFixed(2)}%';
  return switch (move) {
    LoopPriceMove.up => '▲ $figure',
    LoopPriceMove.down => '▼ $figure',
    LoopPriceMove.flat || LoopPriceMove.unread => figure,
  };
}

/// The short phrase a row prints where its price would be when the quote
/// was not read (decision 0100 §12). The server's reason, said in a few words;
/// never a zero and never a dash.
String marketQuoteUnavailableLabel(String? reasonCode) => switch (reasonCode) {
  'MARKET_CHAIN_NOT_PRICED' => '暂无报价',
  'MARKET_PROVIDER_RATE_LIMITED' => '行情限流中',
  'MARKET_PROVIDER_UNREACHABLE' => '行情暂时取不到',
  'MARKET_PROVIDER_DEXSCREENER_DISABLED' => '行情源未开启',
  'MARKET_PAIR_NOT_FOUND' => '没有交易对',
  'MARKET_PAIR_UNREPRESENTABLE' => '交易对无法报价',
  'MARKET_FACT_NOT_REPORTED' => '行情源未报告',
  'MARKET_FACT_CACHE_UNAVAILABLE' => '行情缓存不可用',
  _ => loopReasonCodeSummaryText(reasonCode),
};

/// The small marker a quote of lesser quality carries on its row.
String? marketQuoteQualityMarker(LoopFactQuality quality) => switch (quality) {
  LoopFactQuality.stale => '延迟',
  LoopFactQuality.proxied => '以 WBNB 计价',
  LoopFactQuality.derived => '按成交价折算',
  LoopFactQuality.fresh || LoopFactQuality.unavailable => null,
};

/// One 情报 · 行情 row: mark · ticker over its second line · price over its
/// move. 64pt tall, no card, a hairline under it.
class MarketFomoRow extends StatelessWidget {
  const MarketFomoRow({
    required this.symbol,
    required this.subtitle,
    super.key,
    this.logoUrl,
    this.price,
    this.change,
    this.unavailableReason,
    this.marker,
    this.onTap,
    this.trend = false,
    this.trendCloses,
  });

  /// A row from one of the three categories.
  ///
  /// [trend] draws the E-design trend column (decision 0247) instead of the
  /// change pill; only the 情报 · 行情 list asks for it.
  factory MarketFomoRow.category(
    MarketCategoryRow row, {
    Key? key,
    VoidCallback? onTap,
    bool trend = false,
  }) {
    final quote = row.quote;
    final cap = quote?.marketCapUsd;
    return MarketFomoRow(
      key: key,
      symbol: row.symbol,
      subtitle: cap == null ? row.name : '市值 ${loopFormatCompactFigure(cap)}',
      logoUrl: row.logoUrl,
      price: quote?.priceUsd,
      change: quote?.change24hPct,
      unavailableReason: quote == null
          ? (row.quoteUnavailableReason ?? 'MARKET_FACT_NOT_REPORTED')
          : null,
      // A pool-derived MEME price says where it came from (decision 0120).
      marker: quote == null
          ? null
          : quote.source == LoopFactSource.poolSlot0
          ? '池子推算'
          : marketQuoteQualityMarker(quote.quality),
      onTap: onTap,
      trend: trend,
      trendCloses: row.trendCloses,
    );
  }

  /// A row from the Watchlist block of the overview. That block carries no
  /// market cap, so the second line names the asset.
  factory MarketFomoRow.watchlist(
    MarketAssetRow row, {
    Key? key,
    VoidCallback? onTap,
    bool trend = false,
  }) {
    final price = row.price;
    final change = row.priceChange24h;
    return MarketFomoRow(
      key: key,
      symbol: row.displayName,
      subtitle: row.asset?.name ?? loopTruncatedAssetId(row.assetId),
      logoUrl: row.logoUrl,
      price: price.isAvailable ? price.value : null,
      change: change.isAvailable ? change.value : null,
      unavailableReason: price.isAvailable
          ? null
          : (price.reasonCode ?? 'MARKET_FACT_NOT_REPORTED'),
      marker: price.isAvailable
          ? marketQuoteQualityMarker(price.quality)
          : null,
      onTap: onTap,
      trend: trend,
      trendCloses: row.trendCloses,
    );
  }

  final String symbol;
  final String subtitle;
  final String? logoUrl;

  /// `null` exactly when [unavailableReason] is set.
  final Decimal? price;

  /// `null` when the provider did not report the move.
  final Decimal? change;
  final String? unavailableReason;
  final String? marker;
  final VoidCallback? onTap;

  /// The E-design trend column (decision 0247) in place of the change pill.
  final bool trend;

  /// The 24-hour series [trend] draws; `null` prints the percentage only.
  /// Ignored without [trend].
  final List<Decimal>? trendCloses;

  @override
  Widget build(BuildContext context) {
    final value = price;
    final move = change;
    final spoken = <String>[
      symbol,
      subtitle,
      ?marker,
      if (value == null)
        marketQuoteUnavailableLabel(unavailableReason)
      else
        marketRowPrice(value),
      if (value != null)
        trend
            ? marketTrendSpoken(move, hasSeries: _hasSeries)
            : move == null
            ? '24 小时涨跌未报告'
            : '24 小时 ${loopFormatPercent(move)}',
    ].join('，');
    return LoopQuoteRow(
      leading: LoopTokenLogo(
        assetSymbol: symbol,
        logoUrl: logoUrl,
        fallbackMonogram: symbol,
        size: marketFomoLogoSize,
      ),
      title: symbol,
      subtitle: subtitle,
      value: value == null ? null : loopFoldedZerosPrice(marketRowPrice(value)),
      valueKey: const ValueKey<String>('market-row-price'),
      valueCaption: value == null
          ? Text(
              marketQuoteUnavailableLabel(unavailableReason),
              key: const ValueKey<String>('market-row-unavailable'),
              style: LoopType.caption.copyWith(color: LoopColors.text3),
            )
          : (marker == null ? null : Text(marker!)),
      trailing: value == null
          ? null
          : KeyedSubtree(
              key: const ValueKey<String>('market-row-change'),
              child: trend
                  ? MarketTrendColumn(
                      change: move,
                      closes: _hasSeries ? trendCloses : null,
                    )
                  : LoopChangePill(change: move),
            ),
      titleMinWidth: trend ? marketTrendTitleMinWidth : null,
      valueMaxWidth: trend ? marketTrendPriceMaxWidth : null,
      trailingSlotWidth: trend ? marketTrendColumnWidth : null,
      onTap: onTap,
      semanticLabel: spoken,
    );
  }

  bool get _hasSeries => (trendCloses?.length ?? 0) > 1;
}

// ---------------------------------------------------------------------------
// 情报 · 行情 trend column (decision 0247, docs/49 E 稿)
// ---------------------------------------------------------------------------

/// The trend column's width: the 24h line and the percentage under it.
const double marketTrendColumnWidth = 96;

/// The 24h line's box inside the column.
const Size marketTrendLineSize = Size(96, 32);

/// The name column's minimum width on a trend row.
const double marketTrendTitleMinWidth = 112;

/// The price column's maximum width on a trend row.
const double marketTrendPriceMaxWidth = 92;

/// The line's inset, as the E design draws it (x 2 → 92, y 3 → 29).
const EdgeInsets marketTrendLinePadding = EdgeInsets.fromLTRB(2, 3, 4, 3);

/// The newest point's dot.
const double marketTrendDotRadius = 2.6;

/// The draw-in of a newly shown line; none when motion is reduced.
const Duration marketTrendDrawIn = Duration(milliseconds: 360);

/// The colour of the line: rise green, fall red, and the grey `line3` for a
/// flat or unreported move (E 稿).
Color marketTrendLineColor(Decimal? change) =>
    switch (LoopPriceMove.of(change)) {
      LoopPriceMove.up => LoopColors.rise,
      LoopPriceMove.down => LoopColors.fall,
      LoopPriceMove.flat || LoopPriceMove.unread => LoopColors.line3,
    };

/// 「24 小时走势上涨 8.40%」 with a line, 「24 小时涨跌 +8.40%」 without one.
String marketTrendSpoken(Decimal? change, {required bool hasSeries}) {
  if (change == null) return '24 小时涨跌未报告';
  final magnitude = change < Decimal.zero ? -change : change;
  final figure = '${magnitude.toStringAsFixed(2)}%';
  if (!hasSeries) return '24 小时涨跌 ${loopSignedPercent(change)}';
  return switch (LoopPriceMove.of(change)) {
    LoopPriceMove.up => '24 小时走势上涨 $figure',
    LoopPriceMove.down => '24 小时走势下跌 $figure',
    LoopPriceMove.flat || LoopPriceMove.unread => '24 小时走势持平 $figure',
  };
}

/// The E-design trend column: a 96 × 32 line of the last 24 hours with a dot
/// on its newest point, and the signed move under it in `figureSm` at 700 —
/// no pill ground. Without a series the line's box stays empty (no dashed
/// placeholder), so every row's percentage sits on the same line and the
/// same right edge.
///
/// The line is a shape: normalised between the series' own low and high, no
/// figure is read from it.
class MarketTrendColumn extends StatelessWidget {
  const MarketTrendColumn({required this.change, super.key, this.closes});

  final Decimal? change;
  final List<Decimal>? closes;

  @override
  Widget build(BuildContext context) {
    final move = change;
    final series = closes;
    final direction = LoopPriceMove.of(move);
    final figureColor = switch (direction) {
      LoopPriceMove.up => LoopColors.rise,
      LoopPriceMove.down => LoopColors.fall,
      LoopPriceMove.flat => LoopGround.inkOf(context),
      LoopPriceMove.unread => LoopColors.text3,
    };
    return Semantics(
      container: true,
      label: marketTrendSpoken(
        move,
        hasSeries: series != null && series.length > 1,
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey<String>('market-trend-column'),
          width: marketTrendColumnWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox.fromSize(
                size: marketTrendLineSize,
                child: series == null || series.length < 2
                    ? null
                    : _MarketTrendLine(
                        closes: series,
                        color: marketTrendLineColor(move),
                      ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  move == null ? '未报告' : loopSignedPercent(move),
                  key: const ValueKey<String>('market-trend-percent'),
                  maxLines: 1,
                  softWrap: false,
                  style: move == null
                      ? LoopType.caption.copyWith(color: LoopColors.text3)
                      : LoopTypography.withWeight(
                          LoopType.figureSm,
                          FontWeight.w700,
                        ).copyWith(color: figureColor, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketTrendLine extends StatelessWidget {
  const _MarketTrendLine({required this.closes, required this.color});

  final List<Decimal> closes;
  final Color color;

  CustomPaint _paint(double progress) => CustomPaint(
    key: const ValueKey<String>('market-trend-line'),
    size: marketTrendLineSize,
    painter: LoopSparklinePainter(
      closes: closes,
      color: color,
      padding: marketTrendLinePadding,
      endDotRadius: marketTrendDotRadius,
      progress: progress,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final duration = LoopMotion.of(context, marketTrendDrawIn);
    return RepaintBoundary(
      child: duration == Duration.zero
          ? _paint(1)
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: duration,
              curve: LoopMotion.enter,
              builder: (context, progress, _) => _paint(progress),
            ),
    );
  }
}

/// Where a scrolled list ends once every page is in: nothing but room
/// (decision 0122, OKX rule 10 — a list that has reached its end draws no
/// 「没有更多」).
class MarketListEnd extends StatelessWidget {
  const MarketListEnd({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

/// The two rows a list shows while its next page is being read.
class MarketListLoadingMore extends StatelessWidget {
  const MarketListLoadingMore({super.key});

  @override
  Widget build(BuildContext context) => const LoopSkeleton(
    type: LoopSkeletonType.priceRow,
    rows: 2,
    rowHeight: marketFomoRowHeight,
    leadingSize: marketFomoLogoSize,
  );
}

// ---------------------------------------------------------------------------
// 情报 · 活动位
// ---------------------------------------------------------------------------

/// The promotion strip at the top of 情报 · 行情 (decision 0100 §13): one
/// card per running promotion, swiped sideways. It is not drawn at all when
/// no card is running.
class IntelPromotionStrip extends StatelessWidget {
  const IntelPromotionStrip({
    required this.promotions,
    required this.onOpen,
    super.key,
  });

  final List<IntelPromotion> promotions;

  /// Opens the card's in-app location.
  final ValueChanged<String> onOpen;

  static const double cardWidth = 248;
  static const double cardHeight = 92;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        key: const ValueKey<String>('intel-promotions'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        itemCount: promotions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final promotion = promotions[index];
          return _IntelPromotionCard(
            key: ValueKey<String>('intel-promotion-${promotion.id}'),
            promotion: promotion,
            onTap: () => onOpen(promotion.deeplink),
          );
        },
      ),
    );
  }
}

class _IntelPromotionCard extends StatelessWidget {
  const _IntelPromotionCard({
    required this.promotion,
    required this.onTap,
    super.key,
  });

  final IntelPromotion promotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = promotion.imageUrl;
    return Semantics(
      button: true,
      label: <String>[
        promotion.title,
        if (promotion.subtitle.isNotEmpty) promotion.subtitle,
      ].join('，'),
      excludeSemantics: true,
      child: Material(
        color: LoopColors.card,
        // OKX card: a flat face, no edge (decision 0122).
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: IntelPromotionStrip.cardWidth,
            height: IntelPromotionStrip.cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (image != null)
                  // S257 (decision 0215): through LoopRemoteAvatar's source
                  // — this device's copy first, then the download — not a
                  // bare network read. A cover, so it decodes at its size.
                  Image(
                    key: const ValueKey<String>('intel-promotion-image'),
                    image: loopRemoteImageSource(image),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // A picture that does not arrive leaves the card's own
                    // ground; the words are on top either way.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        promotion.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.title,
                      ),
                      if (promotion.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          promotion.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.caption.copyWith(
                            color: LoopColors.text2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child: LoopIcon('chevron', size: 14, color: LoopColors.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the next cursor page once this marker comes within reach of the
/// bottom of the scroll view it sits in.
///
/// [LoopLoadMoreSentinel] fires when it is *built*, which is right for a row
/// of a lazily built list and wrong for a marker inside a block that is built
/// whole: there it would read every page at once. This one measures where it
/// is on each scroll and asks only when the reader is near it. Each cursor is
/// asked for once.
class MarketVisibleSentinel extends StatefulWidget {
  const MarketVisibleSentinel({
    required this.cursor,
    required this.onLoadMore,
    super.key,
    this.reach = 240,
  });

  final String cursor;
  final VoidCallback onLoadMore;

  /// How far below the visible bottom the marker may be and still ask.
  final double reach;

  @override
  State<MarketVisibleSentinel> createState() => _MarketVisibleSentinelState();
}

class _MarketVisibleSentinelState extends State<MarketVisibleSentinel> {
  String? _asked;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_check);
      _position = next;
      _position?.addListener(_check);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(covariant MarketVisibleSentinel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _asked == widget.cursor) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();
    final double bottom;
    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      bottom = viewport.localToGlobal(Offset.zero).dy + viewport.size.height;
    } else {
      bottom = MediaQuery.sizeOf(context).height;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    if (top > bottom + widget.reach) return;
    _asked = widget.cursor;
    widget.onLoadMore();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 1);
}
