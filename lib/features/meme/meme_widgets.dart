import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

/// The logo slot on the token page header: 44pt, corner radius 10.
const double memeLogoSize = 44;

/// The round logo on a Launch v2 row (decision 0122, OKX rule 1). The MEME
/// 经典 rows draw [memeRowLogoSize] since decision 0173.
const double memeCardLogoSize = 36;

/// A Launch v2 row's height, and a 经典 row's: 14 + the 44 tile + 14 is the
/// OKX quote row's 72 (decisions 0122 / 0173).
const double memeCardHeight = loopQuoteRowHeight;

/// The monogram ground a token without a picture is given: the four quiet
/// grounds of [communityLogoGrounds], never full or pale Lime. On the
/// launchpad Lime belongs to the progress ring; a column of Lime tiles beside
/// it would drown the one thing the card is for (decision 0122).
CommunityLogoGround memeLogoGroundFor(String identity) {
  final quiet = <CommunityLogoGround>[
    for (final ground in communityLogoGrounds)
      if (ground.id != 'lime' && ground.id != 'lime-pale') ground,
  ];
  return quiet[communityLogoHash(identity.trim()) % quiet.length];
}

/// A token's square picture, over a monogram tile that is on screen from the
/// first frame.
///
/// With an [identity] the monogram takes the stable ground that identity is
/// given (the same six grounds a community without a preset gets), so a list
/// of tokens with no picture is not a column of identical grey tiles.
class MemeLogo extends StatelessWidget {
  const MemeLogo({
    required this.symbol,
    super.key,
    this.imageUrl,
    this.size = memeLogoSize,
    this.radius,
    this.identity,
  });

  final String symbol;
  final String? imageUrl;
  final double size;
  final double? radius;
  final String? identity;

  @override
  Widget build(BuildContext context) {
    final letters = symbol.isEmpty
        ? ''
        : symbol.substring(0, symbol.length < 2 ? symbol.length : 2);
    final corner = radius ?? size * 10 / memeLogoSize;
    final ground = identity == null ? null : memeLogoGroundFor(identity!);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ground?.fill ?? LoopColors.card2,
        borderRadius: BorderRadius.circular(corner),
        border: ground == null ? Border.all(color: LoopColors.line) : null,
      ),
      // Decision 0149: before a ticker is typed (the create pages' preview)
      // the slot shows the upload glyph, not a 「?」 that read as an error.
      child: symbol.isEmpty
          ? LoopIcon(
              'camera',
              key: const ValueKey<String>('meme-logo-empty'),
              size: size / 3,
              color: LoopColors.text3,
            )
          : Text(
              letters,
              maxLines: 1,
              style: ground == null
                  ? LoopType.label.copyWith(color: LoopColors.chalk)
                  : LoopTypography.figure(
                      size / 3.2,
                      weight: FontWeight.w700,
                      color: ground.ink,
                    ),
            ),
    );
    final url = imageUrl;
    if (url == null) return fallback;
    return LoopRemoteAvatar(
      url: url,
      fallback: fallback,
      size: size,
      shape: BoxShape.rectangle,
      radius: corner,
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

/// The short percentage printed inside a progress ring: `0%`, `<0.1%`,
/// `0.1%`…`9.9%`, then whole numbers up to `100%`. The exact figure stays in
/// the ring's semantics and on the token page ([memeBpsLabel]).
String memeRingLabel(int bps) {
  final clamped = bps.clamp(0, 10000);
  if (clamped == 0) return '0%';
  if (clamped < 10) return '<0.1%';
  if (clamped < 1000) {
    final tenths = clamped ~/ 10;
    final whole = tenths ~/ 10;
    final fraction = tenths % 10;
    return fraction == 0 ? '$whole%' : '$whole.$fraction%';
  }
  return '${clamped ~/ 100}%';
}

/// The curve's progress as a ring (decision 0122): a Lime arc over a faint
/// track with the short percentage inside. A graduated token is a solid Lime
/// disc with the graduation cap, and 「已毕业」 under it when [caption] is on.
class MemeProgressRing extends StatelessWidget {
  const MemeProgressRing({
    required this.progressBps,
    required this.graduated,
    super.key,
    this.size = 40,
    this.caption = true,
  });

  final int progressBps;
  final bool graduated;
  final double size;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    if (graduated) {
      final disc = Container(
        key: const ValueKey<String>('meme-ring-graduated'),
        width: size,
        height: size,
        alignment: Alignment.center,
        // A closed ring on Lime's soft ground: complete, without a solid
        // Lime disc on every graduated card of the list.
        decoration: BoxDecoration(
          color: LoopColors.limeSoft,
          shape: BoxShape.circle,
          border: Border.all(
            color: LoopColors.lime,
            width: size >= 44 ? 4 : 3.5,
          ),
        ),
        child: LoopIcon('graduate', size: size * 0.45, color: LoopColors.lime),
      );
      return Semantics(
        label: '已毕业',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              disc,
              if (caption) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  '已毕业',
                  maxLines: 1,
                  style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final fraction = memeProgressFraction(progressBps);
    final duration = LoopMotion.of(context, LoopMotion.progressFill);
    final stroke = size >= 44 ? 4.0 : 3.5;
    return Semantics(
      label: '内盘进度 ${memeBpsLabel(progressBps)}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction),
            duration: duration,
            curve: LoopMotion.progressCurve,
            builder: (context, value, child) => CustomPaint(
              key: const ValueKey<String>('meme-progress-ring'),
              painter: _MemeRingPainter(fraction: value, stroke: stroke),
              child: child,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(stroke + 1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    memeRingLabel(progressBps),
                    maxLines: 1,
                    // R7 at 700; the FittedBox shrinks it inside the small
                    // ring (it used to ask for 10, under the 11 floor).
                    style: LoopTypography.withWeight(
                      LoopType.figureXs,
                      FontWeight.w700,
                    ).copyWith(color: LoopColors.chalk),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemeRingPainter extends CustomPainter {
  const _MemeRingPainter({required this.fraction, required this.stroke});

  final double fraction;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = LoopColors.line;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    final sweep = fraction.clamp(0.0, 1.0) * math.pi * 2;
    if (sweep <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = LoopColors.lime;
    // A sliver under one degree still shows as a dot, so a token that has
    // started its curve never reads as one that has not.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.max(sweep, math.pi / 180),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_MemeRingPainter old) =>
      old.fraction != fraction || old.stroke != stroke;
}

/// What a card or a hero says aloud.
String memeTokenSpokenLabel(MemeTokenRow row) {
  final price = row.priceUsd1;
  final cap = row.marketCapUsd1;
  final change = row.change1hPct;
  return <String>[
    '${row.name} ${loopTickerLabel(row.symbol)}',
    if (price == null)
      memeQuoteUnavailableText(row.quoteUnavailableReason)
    else
      memePriceLabel(price),
    if (change != null) '1h ${marketMoveLabel(change)}' else '1h 涨跌未报告',
    if (cap != null) '市值 ${memeCapLabel(cap)}',
    '${row.holderCount} 持有',
    if (row.isGraduated) '已毕业' else '内盘进度 ${memeBpsLabel(row.progressBps)}',
  ].join('，');
}

/// The logo on a launchpad row: the 44 `.tile-img` (decision 0173).
const double memeRowLogoSize = 44;

/// The progress track's width on a launchpad row (`.prog .bar`, 56 px).
const double memeRowProgressWidth = 56;

/// One launchpad row, design 35 「列表 A」 (decision 0173): the 44 r15 tile;
/// the ticker with its age (or 「已毕业」) over 「交易量 · 名称」; on the
/// right 「市值」 over a 56 px bar and its percentage — or, once graduated,
/// the one-hour move. Shared by the four 经典 sub-lists. The price, the
/// holder count and the exact progress are on the token page; the row says
/// them aloud.
class MemeTokenCard extends StatelessWidget {
  const MemeTokenCard({
    required this.row,
    super.key,
    this.onTap,
    this.now,
    this.divider = true,
  });

  final MemeTokenRow row;
  final VoidCallback? onTap;

  /// The moment the age is measured from: the page's own observation time
  /// when the list passes it, the device clock otherwise.
  final DateTime? now;

  /// `.row` draws a Line hairline under itself; the last row of a list
  /// (`.row:last-child`) does not.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final cap = row.marketCapUsd1;
    final volume = row.volume24hUsd1;
    final createdAt = row.createdAt;
    final age = createdAt == null ? null : memeAgeLabel(createdAt, now: now);
    final title = Row(
      children: <Widget>[
        Flexible(
          child: Text(
            row.symbol,
            key: const ValueKey<String>('meme-row-ticker'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            // The quote-row title (decision 0190 H4): the same 16 as 情报·行情.
            style: LoopType.titleLg,
          ),
        ),
        if (row.isGraduated) ...<Widget>[
          const SizedBox(width: 6),
          const LoopBadge(
            '已毕业',
            key: ValueKey<String>('meme-graduated-tag'),
            kind: LoopBadgeKind.launch,
          ),
        ] else if (age != null) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            age,
            key: const ValueKey<String>('meme-row-age'),
            maxLines: 1,
            softWrap: false,
            // R7 at 600 (decision 0190 M27; it was 10, under the floor).
            style: LoopTypography.withWeight(
              LoopType.figureXs,
              FontWeight.w600,
            ).copyWith(color: LoopColors.lime),
          ),
        ],
      ],
    );
    final subtitle = Text(
      <String>[
        if (volume != null) '${memeCapLabel(volume)} 交易量',
        row.name,
      ].join(' · '),
      key: const ValueKey<String>('meme-row-subtitle'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: LoopType.bodySm,
    );
    final value = cap == null
        ? Text(
            memeQuoteUnavailableText(row.quoteUnavailableReason),
            key: const ValueKey<String>('meme-row-cap-unavailable'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: LoopType.caption.copyWith(color: LoopColors.text3),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '市值 ${memeCapLabel(cap)}',
              key: const ValueKey<String>('meme-row-cap'),
              maxLines: 1,
              softWrap: false,
              // The quote-row value (decision 0190 H4).
              style: LoopType.figureMd,
            ),
          );
    final change = row.change1hPct;
    final Widget? foot = row.isGraduated
        // An unreported move draws nothing rather than a dash or a zero.
        ? change == null
              ? null
              : Text(
                  '${loopSignedPercent(change)} 1h',
                  key: const ValueKey<String>('meme-change'),
                  maxLines: 1,
                  softWrap: false,
                  style: LoopTypography.withWeight(
                    LoopType.figureSm,
                    FontWeight.w600,
                  ).copyWith(color: LoopPriceMove.of(change).color, height: 1),
                )
        : _MemeRowProgress(progressBps: row.progressBps);
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 14,
      ),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: LoopColors.line)),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: <Widget>[
            MemeLogo(
              symbol: row.symbol,
              imageUrl: row.imageUrl,
              identity: row.memeTokenId,
              size: memeRowLogoSize,
              radius: LoopRadius.tileValue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[title, const SizedBox(height: 2), subtitle],
              ),
            ),
            const SizedBox(width: 12),
            // `.row-end`: as wide as its figures, never more than two fifths
            // of the row, so the ticker keeps its room on a narrow phone.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 2 / 5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  value,
                  if (foot != null) ...<Widget>[
                    const SizedBox(height: 6),
                    foot,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: <String>[
        memeTokenSpokenLabel(row),
        if (volume != null) '交易量 ${memeCapLabel(volume)}',
        if (!row.isGraduated && age != null) '上线 $age',
      ].join('，'),
      excludeSemantics: true,
      child: tap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey<String>('meme-row-${row.memeTokenId}'),
                onTap: tap,
                // `.row:active{background:var(--card2)}`
                highlightColor: LoopColors.card2,
                child: content,
              ),
            ),
    );
  }
}

/// `.prog`: the 56 px `.bar` and the short percentage in Lime beside it.
class _MemeRowProgress extends StatelessWidget {
  const _MemeRowProgress({required this.progressBps});

  final int progressBps;

  @override
  Widget build(BuildContext context) {
    final fraction = memeProgressFraction(progressBps);
    final duration = LoopMotion.of(context, LoopMotion.progressFill);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          key: const ValueKey<String>('meme-row-progress'),
          width: memeRowProgressWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction),
            duration: duration,
            curve: LoopMotion.progressCurve,
            builder: (context, value, _) => LoopProgressBar(
              // A curve that has started never reads as empty.
              value: value <= 0 ? 0 : value.clamp(0.04, 1),
              semanticLabel: '内盘进度 ${memeBpsLabel(progressBps)}',
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          memeRingLabel(progressBps),
          key: const ValueKey<String>('meme-progress-label'),
          maxLines: 1,
          softWrap: false,
          style: LoopTypography.withWeight(
            LoopType.figureSm,
            FontWeight.w600,
            // Line height 1 keeps the 44 tile the row's tallest part.
          ).copyWith(color: LoopColors.lime, height: 1),
        ),
      ],
    );
  }
}

/// The 「快打满」 strip's card (decision 0122): 220 × 120, a 48 logo with
/// the 44 ring beside it, then the name and 「$SYMBOL · 市值」.
class MemeHeroCard extends StatelessWidget {
  const MemeHeroCard({required this.row, super.key, this.onTap});

  static const double width = 220;
  static const double height = 120;

  final MemeTokenRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cap = row.marketCapUsd1;
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: memeTokenSpokenLabel(row),
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          // OKX card: a flat grey face, no edge and no shadow.
          color: LoopColors.card2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('meme-hero-${row.memeTokenId}'),
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MemeLogo(
                        symbol: row.symbol,
                        imageUrl: row.imageUrl,
                        identity: row.memeTokenId,
                        size: 48,
                        radius: 12,
                      ),
                      const Spacer(),
                      MemeProgressRing(
                        progressBps: row.progressBps,
                        graduated: row.isGraduated,
                        size: 44,
                        caption: false,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: LoopType.title,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      loopTickerLabel(row.symbol),
                      if (cap != null) '市值 ${memeCapLabel(cap)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
            ),
          ),
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
