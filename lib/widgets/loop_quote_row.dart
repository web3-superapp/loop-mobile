import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

/// The row height of an OKX-shaped quote list (decision 0122, S121 §1.1.1).
// 74 since decision 0210: the 1.35 title and 1.7 grey line of the new ladder.
const double loopQuoteRowHeight = 74;

/// The fixed size of the change pill at the right end of a quote row.
const Size loopChangePillSize = Size(96, 44);

/// The corner of that slot's pill, shared by [LoopChangePill] and the MEME
/// list's progress pill so the two read as one column (decision 0122).
const BorderRadius loopChangePillRadius = LoopRadius.badge;

/// `+2.50%` / `-1.01%` / `0.00%`: a move in percent points, signed.
String loopSignedPercent(Decimal percent) {
  final magnitude = percent < Decimal.zero ? -percent : percent;
  final figure = '${magnitude.toStringAsFixed(2)}%';
  return switch (LoopPriceMove.of(percent)) {
    LoopPriceMove.up => '+$figure',
    LoopPriceMove.down => '-$figure',
    LoopPriceMove.flat || LoopPriceMove.unread => figure,
  };
}

const List<String> _subscriptDigits = <String>[
  '₀',
  '₁',
  '₂',
  '₃',
  '₄',
  '₅',
  '₆',
  '₇',
  '₈',
  '₉',
];

/// A printed price with a long run of leading zeros folded into a subscript
/// count: `$0.000005601` → `$0.0₅5601`. Prices with fewer than four leading
/// zeros are returned unchanged. The full figure stays in the semantics.
String loopFoldedZerosPrice(String printed) {
  final match = RegExp(r'^(\$?)0\.(0{4,})(\d+)$').firstMatch(printed);
  if (match == null) return printed;
  final count = match.group(2)!.length;
  final subscript = <String>[
    for (final digit in '$count'.split('')) _subscriptDigits[int.parse(digit)],
  ].join();
  return '${match.group(1)}0.0$subscript${match.group(3)}';
}

/// The OKX change pill: a fixed 96 × 44 block on the move's soft ground with
/// the signed figure in the move's colour, `LoopType.figure` at 700 (13 bold
/// since decision 0189 S1; it was 16). A move that was not
/// reported is the same block on the card ground with a weak 「未报告」.
class LoopChangePill extends StatelessWidget {
  const LoopChangePill({required this.change, super.key});

  final Decimal? change;

  @override
  Widget build(BuildContext context) {
    final move = change;
    final direction = LoopPriceMove.of(move);
    final ground = switch (direction) {
      LoopPriceMove.up => LoopColors.riseSoft,
      LoopPriceMove.down => LoopColors.fallSoft,
      LoopPriceMove.flat || LoopPriceMove.unread => LoopColors.card2,
    };
    return Container(
      key: const ValueKey<String>('loop-change-pill'),
      width: loopChangePillSize.width,
      height: loopChangePillSize.height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: loopChangePillRadius,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          move == null ? '未报告' : loopSignedPercent(move),
          maxLines: 1,
          style: move == null
              ? LoopType.caption.copyWith(color: LoopColors.text3)
              : LoopTypography.withWeight(
                  LoopType.figure,
                  FontWeight.w700,
                ).copyWith(color: direction.color),
        ),
      ),
    );
  }
}

/// One OKX-shaped quote row (decision 0122, ladder per decision 0189 S1): a
/// round mark, two lines on the left (`LoopType.titleLg` 16 over a
/// `LoopType.bodySm` 13 grey line), two lines on the right (`LoopType.figureMd`
/// 17 over a `LoopType.figureSm` 12 grey line) and an optional fixed trailing
/// block — the change pill. No card and no hairline: rows are separated by their height.
class LoopQuoteRow extends StatelessWidget {
  const LoopQuoteRow({
    required this.leading,
    required this.title,
    super.key,
    this.titleTrailing,
    this.subtitle,
    this.subtitleMark,
    this.subtitleMarkKey,
    this.value,
    this.valueKey,
    this.valueCaption,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.tapKey,
    this.height = loopQuoteRowHeight,
    this.titleMinWidth,
  });

  final Widget leading;
  final String title;

  /// A small mark right after the title (a ticker capsule).
  final Widget? titleTrailing;
  final String? subtitle;

  /// A derived-figure note at the end of the grey line, in small weak type
  /// (「以 WBNB 计价」, 「待确认 0.1」). On a narrow row both parts give way.
  final String? subtitleMark;
  final Key? subtitleMarkKey;
  final String? value;
  final Key? valueKey;
  final Widget? valueCaption;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Key? tapKey;
  final double height;

  /// The width the title keeps however wide the figures are (decision 0146):
  /// the figure column gives way — a figure scales down, a caption ends in an
  /// ellipsis — before the ticker does. `null` keeps the 140 / 36 % cap only.
  final double? titleMinWidth;

  /// The figure column's cap: 140 or 36 % of the row, and — with
  /// [titleMinWidth] — no wider than what is left once the leading slot
  /// ([leadingWidth]), the title's minimum, the gaps and the trailing slot
  /// ([trailingWidth]) are paid for.
  double _valueMaxWidth(double rowWidth) {
    final cap = math.min(140, rowWidth * 0.36).toDouble();
    final minimum = titleMinWidth;
    if (minimum == null) return cap;
    final left =
        rowWidth -
        leadingWidth -
        12 -
        minimum -
        10 -
        (trailing == null ? 0 : trailingWidth + 12);
    return math.max(56, math.min(cap, left));
  }

  /// The leading slot's width, as [titleMinWidth] budgets it (the 36 logo
  /// every quote list draws).
  static const double leadingWidth = 36;

  /// The trailing slot's width, as [titleMinWidth] budgets it: the fixed
  /// change-pill slot.
  static double get trailingWidth => loopChangePillSize.width;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: <Widget>[
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: LoopType.titleLg,
                          ),
                        ),
                        if (titleTrailing != null) ...<Widget>[
                          const SizedBox(width: 6),
                          titleTrailing!,
                        ],
                      ],
                    ),
                    if (subtitle != null || subtitleMark != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          if (subtitle != null)
                            Flexible(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: LoopType.bodySm,
                              ),
                            ),
                          if (subtitleMark != null) ...<Widget>[
                            if (subtitle != null) const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subtitleMark!,
                                key: subtitleMarkKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: LoopType.captionSm,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null || valueCaption != null) ...<Widget>[
                const SizedBox(width: 10),
                // As wide as its figures and no wider (decision 0123): the
                // left column takes the rest, so every row's pill ends on the
                // same right edge. The cap shrinks on a narrow screen so the
                // block never overflows (a 320pt phone).
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _valueMaxWidth(constraints.maxWidth),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (value != null)
                        // A figure is never cut: on a narrow screen it
                        // scales down instead of ending in an ellipsis.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            value!,
                            key: valueKey,
                            maxLines: 1,
                            softWrap: false,
                            style: LoopType.figureMd.copyWith(
                              color: LoopGround.inkOf(context),
                            ),
                          ),
                        ),
                      if (valueCaption != null) ...<Widget>[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: LoopType.figureSm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: valueCaption!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
    final tap = onTap;
    final body = tap == null
        ? row
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: tapKey,
              onTap: tap,
              highlightColor: LoopColors.card2,
              child: row,
            ),
          );
    if (semanticLabel == null) return body;
    return Semantics(
      button: tap != null,
      // excludeSemantics drops the InkWell's own tap action; keep it so a
      // screen reader can activate the row (decision 0219).
      onTap: tap,
      label: semanticLabel,
      excludeSemantics: true,
      child: body,
    );
  }
}
