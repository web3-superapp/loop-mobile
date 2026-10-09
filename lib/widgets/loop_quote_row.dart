import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

/// The row height of an OKX-shaped quote list (decision 0122, S121 §1.1.1).
const double loopQuoteRowHeight = 72;

/// The fixed size of the change pill at the right end of a quote row.
const Size loopChangePillSize = Size(96, 44);

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
/// the signed figure in the move's colour, 16 bold. A move that was not
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
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          move == null ? '未报告' : loopSignedPercent(move),
          maxLines: 1,
          style: move == null
              ? LoopType.caption.copyWith(color: LoopColors.text3)
              : LoopTypography.figure(
                  16,
                  weight: FontWeight.w700,
                  color: direction.color,
                ),
        ),
      ),
    );
  }
}

/// One OKX-shaped quote row (decision 0122): a round mark, two lines on the
/// left (title 18 bold over a 14 grey line), two lines on the right (figure
/// 18 bold over a 14 grey line) and an optional fixed trailing block — the
/// change pill. No card and no hairline: rows are separated by their height.
class LoopQuoteRow extends StatelessWidget {
  const LoopQuoteRow({
    required this.leading,
    required this.title,
    super.key,
    this.titleTrailing,
    this.subtitle,
    this.value,
    this.valueKey,
    this.valueCaption,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.tapKey,
    this.height = loopQuoteRowHeight,
  });

  final Widget leading;
  final String title;

  /// A small mark right after the title (a ticker capsule).
  final Widget? titleTrailing;
  final String? subtitle;
  final String? value;
  final Key? valueKey;
  final Widget? valueCaption;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Key? tapKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Row(
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
                          style: LoopTypography.title(18),
                        ),
                      ),
                      if (titleTrailing != null) ...<Widget>[
                        const SizedBox(width: 6),
                        titleTrailing!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: LoopTypography.body(14, color: LoopColors.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null || valueCaption != null) ...<Widget>[
              const SizedBox(width: 10),
              // Shares the room with the left column on a narrow screen, so
              // the trailing block never overflows (a 320pt phone).
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
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
                            style: LoopTypography.figure(
                              18,
                              weight: FontWeight.w700,
                              color: LoopGround.inkOf(context),
                            ),
                          ),
                        ),
                      if (valueCaption != null) ...<Widget>[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: LoopTypography.body(
                            14,
                            color: LoopColors.text2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: valueCaption!,
                        ),
                      ],
                    ],
                  ),
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
      label: semanticLabel,
      excludeSemantics: true,
      child: body,
    );
  }
}
