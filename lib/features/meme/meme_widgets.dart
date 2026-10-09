import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

/// The logo slot on the token page header: 44pt, corner radius 10.
const double memeLogoSize = 44;

/// The round logo on a launchpad row (decision 0122, OKX rule 1).
const double memeCardLogoSize = 36;

/// A launchpad row's height: the OKX quote row (decision 0122).
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
        ? '?'
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
      child: Text(
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
                    style: LoopTypography.figure(
                      size >= 44 ? 11 : 10,
                      weight: FontWeight.w700,
                      color: LoopColors.chalk,
                    ),
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
    '${row.name} \$${row.symbol}',
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

/// The curve's progress in the quote row's fixed 96 × 44 slot: the short
/// percentage in Lime over a 4px Lime bar (decision 0123; a ring-and-figure
/// pill was built and compared on the emulator and lost on legibility). A
/// graduated token's pill is unchanged from decision 0122: Lime-soft, the
/// cap and 「已毕业」.
class MemeProgressPill extends StatelessWidget {
  const MemeProgressPill({required this.row, super.key});

  final MemeTokenRow row;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(10));
    final size = loopChangePillSize;
    if (row.isGraduated) {
      return Container(
        key: const ValueKey<String>('meme-graduated-tag'),
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          color: LoopColors.limeSoft,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const LoopIcon('graduate', size: 16, color: LoopColors.lime),
            const SizedBox(width: 4),
            Text(
              '已毕业',
              style: LoopTypography.title(14, color: LoopColors.lime),
            ),
          ],
        ),
      );
    }
    final fraction = memeProgressFraction(row.progressBps);
    final label = Text(
      memeRingLabel(row.progressBps),
      key: const ValueKey<String>('meme-progress-label'),
      maxLines: 1,
      style: LoopTypography.figure(
        16,
        weight: FontWeight.w700,
        color: LoopColors.lime,
        height: 1,
      ),
    );
    final duration = LoopMotion.of(context, LoopMotion.progressFill);
    // Decision 0123: the percentage over a 4px Lime bar, the bar's track the
    // pill's own line colour. The pill no longer fills behind the figure.
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: const BoxDecoration(
        color: LoopColors.card2,
        borderRadius: radius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(fit: BoxFit.scaleDown, child: label),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            child: SizedBox(
              height: 4,
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
                      // A curve that has started never reads as empty.
                      widthFactor: value <= 0 ? 0 : value.clamp(0.04, 1),
                      child: const ColoredBox(color: LoopColors.lime),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One launchpad row in the OKX quote shape (decision 0122, S121 §1.1.1):
/// logo · ticker over 市值 · price over its one-hour move · the progress
/// pill in the fixed right slot. The name and the holder count are on the
/// token page; the row says them aloud.
class MemeTokenCard extends StatelessWidget {
  const MemeTokenCard({required this.row, super.key, this.onTap});

  final MemeTokenRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = row.priceUsd1;
    final cap = row.marketCapUsd1;
    final change = row.change1hPct;
    return LoopQuoteRow(
      tapKey: ValueKey<String>('meme-row-${row.memeTokenId}'),
      leading: MemeLogo(
        symbol: row.symbol,
        imageUrl: row.imageUrl,
        identity: row.memeTokenId,
        size: memeCardLogoSize,
        radius: memeCardLogoSize / 2,
      ),
      title: row.symbol,
      subtitle: cap == null ? row.name : '市值 ${memeCapLabel(cap)}',
      value: price == null ? null : loopFoldedZerosPrice(memePriceLabel(price)),
      valueKey: const ValueKey<String>('meme-row-price'),
      valueCaption: price == null
          ? Text(
              memeQuoteUnavailableText(row.quoteUnavailableReason),
              key: const ValueKey<String>('meme-row-price-unavailable'),
              style: LoopType.caption.copyWith(color: LoopColors.text3),
            )
          : change == null
          ? null
          : Text(
              '${loopSignedPercent(change)} 1h',
              key: const ValueKey<String>('meme-change'),
              style: LoopTypography.figure(
                14,
                weight: FontWeight.w600,
                color: LoopPriceMove.of(change).color,
              ),
            ),
      trailing: MemeProgressPill(row: row),
      onTap: onTap,
      semanticLabel: memeTokenSpokenLabel(row),
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
                      '\$${row.symbol}',
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
