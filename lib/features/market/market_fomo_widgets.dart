import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

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
const double marketFomoRowHeight = 64;

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
  'MARKET_CHAIN_NOT_PRICED' => '测试网代币不报价',
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
  });

  /// A row from one of the three categories.
  factory MarketFomoRow.category(
    MarketCategoryRow row, {
    Key? key,
    VoidCallback? onTap,
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
      marker: quote == null ? null : marketQuoteQualityMarker(quote.quality),
      onTap: onTap,
    );
  }

  /// A row from the Watchlist block of the overview. That block carries no
  /// market cap, so the second line names the asset.
  factory MarketFomoRow.watchlist(
    MarketAssetRow row, {
    Key? key,
    VoidCallback? onTap,
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

  @override
  Widget build(BuildContext context) {
    final value = price;
    final move = change;
    final secondary = <String>[subtitle, ?marker].join(' · ');
    final spoken = <String>[
      symbol,
      secondary,
      if (value == null)
        marketQuoteUnavailableLabel(unavailableReason)
      else
        marketRowPrice(value),
      if (value != null)
        move == null ? '24 小时涨跌未报告' : '24 小时 ${loopFormatPercent(move)}',
    ].join('，');
    final row = Container(
      height: marketFomoRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          LoopTokenLogo(
            assetSymbol: symbol,
            logoUrl: logoUrl,
            fallbackMonogram: symbol,
            size: marketFomoLogoSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.titleLg,
                ),
                const SizedBox(height: 3),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (value == null)
            SizedBox(
              width: marketFomoUnavailableWidth,
              child: LoopInlineUnavailable(
                key: const ValueKey<String>('market-row-unavailable'),
                message: marketQuoteUnavailableLabel(unavailableReason),
                padding: EdgeInsets.zero,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    marketRowPrice(value),
                    key: const ValueKey<String>('market-row-price'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: marketRowPriceStyle.copyWith(
                      color: LoopPriceMove.of(move).color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    move == null ? '涨跌未报告' : marketMoveLabel(move),
                    key: const ValueKey<String>('market-row-change'),
                    maxLines: 1,
                    softWrap: false,
                    style: LoopType.figureSm.copyWith(
                      color: move == null
                          ? LoopColors.text3
                          : LoopPriceMove.of(move).color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) {
      return Semantics(label: spoken, excludeSemantics: true, child: row);
    }
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          highlightColor: LoopColors.card2,
          child: row,
        ),
      ),
    );
  }
}

/// The weak line a scrolled list ends on once every page is in.
class MarketListEnd extends StatelessWidget {
  const MarketListEnd({super.key, this.text = '没有更多'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: LoopType.captionSm.copyWith(color: LoopColors.text3),
    ),
  );
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
        shape: RoundedRectangleBorder(
          borderRadius: LoopRadius.card,
          side: const BorderSide(color: LoopColors.line),
        ),
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
                  Image.network(
                    image,
                    fit: BoxFit.cover,
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
                  child: LoopIcon('chevron', size: 14, color: LoopColors.lime),
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
