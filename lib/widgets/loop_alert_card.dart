import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// UX-010 (decision 0254): the one shape an in-page warning takes.
///
/// A warning is a card: the Amber hairline on the deep Amber ground, the warn
/// glyph on the left, a bold title and the sentence under it — the same card
/// the risk notice on 关于 already draws. The bare two grey lines a missing
/// block used to print were the same fact in a second dialect; they now use
/// this card's [compact] form, which keeps the shape and only gives up room.
class LoopAlertCard extends StatelessWidget {
  const LoopAlertCard({
    required this.title,
    super.key,
    this.body,
    this.icon = 'warn',
    this.compact = false,
    this.margin = EdgeInsets.zero,
    this.bodyMaxLines,
  });

  /// What is wrong, in a few words. Bold.
  final String title;

  /// Why, or what it affects. Optional.
  final String? body;

  final String icon;

  /// The tighter form a block-level gap takes inside a page.
  final bool compact;

  final EdgeInsets margin;

  /// A cap on [body]'s lines; `null` lets it run.
  final int? bodyMaxLines;

  /// The card's ground and edge, shared with anything that has to match it.
  static Color get ground => LoopColors.warning.withValues(alpha: 0.13);
  static Color get edge => LoopColors.warning.withValues(alpha: 0.44);

  @override
  Widget build(BuildContext context) {
    final bodyStyle = (compact ? LoopType.captionSm : LoopType.caption)
        .copyWith(color: LoopColors.chalk);
    final titleStyle = LoopTypography.withWeight(bodyStyle, FontWeight.w700);
    final text = body;
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        label: text == null ? title : '$title。$text',
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey<String>('loop-alert-card'),
            width: double.infinity,
            padding: compact
                ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                : const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: ground,
              borderRadius: LoopRadius.control,
              border: Border.all(color: edge),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: LoopIcon(
                    icon,
                    size: compact ? 15 : 17,
                    color: LoopColors.chalk,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: titleStyle),
                      if (text != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          text,
                          maxLines: bodyMaxLines,
                          overflow: bodyMaxLines == null
                              ? null
                              : TextOverflow.ellipsis,
                          style: bodyStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
