import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

/// One launchpad row is 72pt tall (S115–S118 §3).
const double memeRowHeight = 72;

/// The logo slot on a row: 44pt, corner radius 10.
const double memeLogoSize = 44;

/// A token's square picture, over a monogram tile that is on screen from the
/// first frame.
class MemeLogo extends StatelessWidget {
  const MemeLogo({
    required this.symbol,
    super.key,
    this.imageUrl,
    this.size = memeLogoSize,
  });

  final String symbol;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = symbol.isEmpty
        ? '?'
        : symbol.substring(0, symbol.length < 2 ? symbol.length : 2);
    final radius = size * 10 / memeLogoSize;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: LoopColors.line),
      ),
      child: Text(
        letters,
        maxLines: 1,
        style: LoopType.label.copyWith(color: LoopColors.chalk),
      ),
    );
    final url = imageUrl;
    if (url == null) return fallback;
    return LoopRemoteAvatar(
      url: url,
      fallback: fallback,
      size: size,
      shape: BoxShape.rectangle,
      radius: radius,
    );
  }
}

/// The curve's progress as a filled track.
///
/// Lime is LOOP's own mark: a progress bar is a LOOP process, not a price
/// direction. [thickness] is 2 on a row and 8 on the token page.
class MemeProgressBar extends StatelessWidget {
  const MemeProgressBar({
    required this.progressBps,
    super.key,
    this.thickness = 2,
  });

  final int progressBps;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final fraction = memeProgressFraction(progressBps);
    final duration = LoopMotion.of(context, LoopMotion.progressFill);
    return Semantics(
      label: '内盘进度 ${memeBpsLabel(progressBps)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(thickness / 2),
        child: SizedBox(
          height: thickness,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: LoopColors.line),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: fraction),
                duration: duration,
                curve: LoopMotion.progressCurve,
                builder: (context, value, _) => FractionallySizedBox(
                  key: const ValueKey<String>('meme-progress-fill'),
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0, 1),
                  child: const ColoredBox(color: LoopColors.lime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「已毕业」, in place of a progress bar.
class MemeGraduatedTag extends StatelessWidget {
  const MemeGraduatedTag({super.key});

  @override
  Widget build(BuildContext context) => const LoopBadge(
    '已毕业',
    key: ValueKey<String>('meme-graduated-tag'),
    kind: LoopBadgeKind.up,
  );
}

/// 「▲ 2.50% · 1h」 in rise / fall; a move that was not reported says so.
class MemeChangeLabel extends StatelessWidget {
  const MemeChangeLabel({
    required this.change,
    super.key,
    this.suffix = '',
    this.style,
  });

  final Decimal? change;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final move = change;
    final base = style ?? LoopType.figureSm;
    if (move == null) {
      return Text(
        '1h 涨跌未报告',
        key: const ValueKey<String>('meme-change-unreported'),
        style: LoopType.captionSm.copyWith(color: LoopColors.text3),
      );
    }
    return Text(
      '${marketMoveLabel(move)}$suffix',
      key: const ValueKey<String>('meme-change'),
      maxLines: 1,
      softWrap: false,
      style: base.copyWith(color: LoopPriceMove.of(move).color),
    );
  }
}

/// One launchpad row: logo · 「名称 $SYMBOL」 over 「市值 · 持有」 · price
/// over its one-hour move, and the curve's progress along the foot. No card.
class MemeTokenRowTile extends StatelessWidget {
  const MemeTokenRowTile({required this.row, super.key, this.onTap});

  final MemeTokenRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = row.priceUsd1;
    final cap = row.marketCapUsd1;
    final secondary = <String>[
      if (cap != null) '市值 ${memeCapLabel(cap)}',
      '${row.holderCount} 持有',
    ].join(' · ');
    final spoken = <String>[
      '${row.name} \$${row.symbol}',
      secondary,
      if (price == null)
        memeQuoteUnavailableText(row.quoteUnavailableReason)
      else
        memePriceLabel(price),
      if (row.isGraduated) '已毕业' else '内盘进度 ${memeBpsLabel(row.progressBps)}',
    ].join('，');
    final body = SizedBox(
      height: memeRowHeight,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
              child: Row(
                children: <Widget>[
                  MemeLogo(symbol: row.symbol, imageUrl: row.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: row.name, style: LoopType.titleLg),
                              TextSpan(
                                text: ' \$${row.symbol}',
                                style: LoopType.caption.copyWith(
                                  color: LoopColors.text2,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.caption.copyWith(
                            color: LoopColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (price == null)
                    Text(
                      memeQuoteUnavailableText(row.quoteUnavailableReason),
                      key: const ValueKey<String>('meme-row-price-unavailable'),
                      style: LoopType.captionSm.copyWith(
                        color: LoopColors.text3,
                      ),
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          memePriceLabel(price),
                          key: const ValueKey<String>('meme-row-price'),
                          maxLines: 1,
                          softWrap: false,
                          style: LoopType.figure,
                        ),
                        const SizedBox(height: 3),
                        if (row.isGraduated)
                          Text(
                            '外盘',
                            style: LoopType.captionSm.copyWith(
                              color: LoopColors.text3,
                            ),
                          )
                        else
                          MemeChangeLabel(change: row.change1hPct),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              6,
            ),
            child: row.isGraduated
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(height: 14, child: MemeGraduatedTag()),
                  )
                : MemeProgressBar(progressBps: row.progressBps),
          ),
        ],
      ),
    );
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: spoken,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('meme-row-${row.memeTokenId}'),
          onTap: tap,
          highlightColor: LoopColors.card2,
          child: body,
        ),
      ),
    );
  }
}

/// The weak source line under a block of curve figures.
class MemeProvenance extends StatelessWidget {
  const MemeProvenance({
    required this.sources,
    super.key,
    this.observedAt,
    this.prefix,
    this.detail,
  });

  final List<String> sources;
  final DateTime? observedAt;
  final String? prefix;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: LoopProvenanceLine(
      sources: sources,
      observedAt: observedAt,
      prefix: prefix,
      detail: detail,
    ),
  );
}

/// The label a price source carries in a source line.
String memePriceSourceLabel(MemePriceProvenance? provenance) =>
    provenance?.source.label ?? MemePriceSource.loopCurve.label;
