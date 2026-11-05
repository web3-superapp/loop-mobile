import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// One OKX-shaped row about a person or an entry (decision 0127): a face on
/// the left, a name with an optional small tag after it, a grey line under it
/// — the one row ladder every list shares since decision 0189 S2
/// (`LoopType.title` 15 over `LoopType.caption` 12 in text2) — and one thing on the right — a figure, a capsule or a chevron.
/// No card and no hairline: rows are told apart by their height, as on the
/// OKX social and asset lists.
class LoopPersonRow extends StatelessWidget {
  const LoopPersonRow({
    required this.leading,
    required this.title,
    super.key,
    this.tag,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.semanticLabel,
    this.height = 64,
    this.titleColor,
    this.divider = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: LoopSpacing.page,
      vertical: 8,
    ),
  });

  /// Draws the Figma's 1 px white 5 % line under the row, across the
  /// content width (S371 · decision 0297, docs/58 §9.4: person and function
  /// rows are ruled). The line is counted inside [height].
  final bool divider;

  /// The space around the row's content. The default is the page margin
  /// and 8 above and below; a Figma-height row passes 6 (decision 0297).
  final EdgeInsets padding;

  /// The [divider] line itself.
  static const Key dividerKey = ValueKey<String>('loop-person-row-divider');

  /// The face: an avatar or a logo at 36–40, or a [LoopEntryIcon].
  final Widget leading;
  final String title;

  /// A small role or state mark after the name (`LoopTag`).
  final Widget? tag;
  final String? subtitle;
  final Widget? trailing;

  /// A grey `›` at the end, for a row that opens a page.
  final bool chevron;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double height;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final face = ConstrainedBox(
      constraints: BoxConstraints(minHeight: divider ? height - 1 : height),
      child: Padding(
        padding: padding,
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
                          style: LoopType.title.copyWith(
                            color: titleColor ?? LoopColors.chalk,
                          ),
                        ),
                      ),
                      if (tag != null) ...<Widget>[
                        const SizedBox(width: 6),
                        tag!,
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
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (chevron) ...<Widget>[
              const SizedBox(width: 8),
              const LoopIcon('chevron', size: 16, color: LoopColors.text3),
            ],
          ],
        ),
      ),
    );
    final row = !divider
        ? face
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              face,
              Padding(
                padding: EdgeInsets.only(
                  left: padding.left,
                  right: padding.right,
                ),
                child: const SizedBox(
                  key: dividerKey,
                  height: 1,
                  child: ColoredBox(color: LoopColors.divider),
                ),
              ),
            ],
          );
    final tap = onTap;
    final body = tap == null
        ? row
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
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

/// The ground a [LoopEntryIcon] draws its glyph on (S371 · decision 0297).
enum LoopEntryIconShape {
  /// Round — a person's place, or an entry that stands in for one.
  circle,

  /// The Figma's function-icon ground: a square at a 9 corner (docs/58
  /// §9.4 「功能图标底 9」).
  square,
}

/// A glyph tile for an entry row that has no face of its own (资料 / 成员 /
/// 语音房 in the manage center, 社区 AI on the record). Round at 40 by
/// default; a function row passes [LoopEntryIconShape.square] (decision
/// 0297).
class LoopEntryIcon extends StatelessWidget {
  const LoopEntryIcon(
    this.icon, {
    super.key,
    this.size = 40,
    this.shape = LoopEntryIconShape.circle,
  });

  final String icon;
  final double size;
  final LoopEntryIconShape shape;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: switch (shape) {
      LoopEntryIconShape.circle => const BoxDecoration(
        color: LoopColors.card2,
        shape: BoxShape.circle,
      ),
      LoopEntryIconShape.square => const BoxDecoration(
        color: LoopColors.card2,
        borderRadius: LoopRadius.glyphGround,
      ),
    },
    child: LoopIcon(icon, size: 20, color: LoopColors.chalk),
  );
}

/// The small mark after a name: 主持 / Owner / Admin / 已验证 / 已禁言.
///
/// [lime] is for the one mark that is the subject's standing (a role that
/// governs, a verified community); everything else is the quiet grey.
class LoopTag extends StatelessWidget {
  const LoopTag(this.text, {super.key, this.lime = false, this.icon});

  final String text;
  final bool lime;

  /// An optional 12 glyph before the word (the verified check).
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = lime ? LoopColors.lime : LoopColors.text2;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: lime ? LoopColors.limeSoft : LoopColors.card2,
        // Decision 0277: the Figma's tag corner.
        borderRadius: LoopRadius.tag,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            LoopIcon(icon!, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            maxLines: 1,
            style: LoopTypography.withWeight(
              LoopType.kicker,
              FontWeight.w600,
            ).copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// A small action at the end of a row — 「接受」 on a request (decision
/// 0127). Yellow when it is the row's one forward step, the raised grey
/// otherwise. The visible face is the compact button's 32, 12 at each side
/// (S325 · decision 0255); the touch target is 44.
///
/// [soft] is the in-list step that must not spend the screen's one solid
/// Yellow (decision 0172, Square's 「加入」). It used to be a Yellow word on a
/// Yellow wash, which read as a tag (UX-007); it is the grey 辅助按钮 now.
class LoopPillAction extends StatelessWidget {
  const LoopPillAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.primary = true,
    this.soft = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ground = !enabled
        ? LoopColors.card2
        : soft
        ? LoopColors.assistFill
        : primary
        ? LoopColors.lime
        // Decision 0211: a secondary chip is the raised ground, no edge.
        : LoopColors.card2;
    final ink = !enabled
        ? LoopColors.text3
        : soft
        ? LoopColors.text2
        : primary
        ? LoopColors.ink
        : LoopColors.chalk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: LoopTouch.compactButton,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ground,
                borderRadius: LoopRadius.button,
              ),
              child: Text(
                label,
                maxLines: 1,
                style: LoopTypography.withWeight(
                  LoopType.titleSm,
                  FontWeight.w600,
                ).copyWith(color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title on a secondary page (decision 0127): 17 semibold on the
/// left and at most one control on the right — 「查看全部 ›」 or an icon.
/// No eyebrow, no English, no count in capitals.
class LoopSectionTitle extends StatelessWidget {
  const LoopSectionTitle(this.title, {super.key, this.trailing, this.top = 24});

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(LoopSpacing.page, top, 8, 4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.sectionTitle,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// The 「查看全部 ›」 control a [LoopSectionTitle] carries.
class LoopSeeAll extends StatelessWidget {
  const LoopSeeAll({required this.onPressed, super.key, this._label});

  final VoidCallback? onPressed;
  final String? _label;
  String get label => _label ?? LoopL10n.current.widgets_personRowLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: LoopPressable(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: LoopType.bodySm),
              const SizedBox(width: 2),
              const LoopIcon('chevron', size: 14, color: LoopColors.text3),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The OKX form field (decision 0127): a 52 tall filled field on the card
/// ground, radius 12, no outline until it has focus or an error. The label
/// stays inside as the hint, so a form is a column of equal fields.
InputDecoration loopFormFieldDecoration({
  required String hint,
  String? error,
  String? counterText,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  errorText: error,
  counterText: counterText,
  suffixIcon: suffix,
  filled: true,
  fillColor: LoopColors.input,
  isDense: true,
  constraints: const BoxConstraints(minHeight: 52),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  // R25: the placeholder is the input step itself (decision 0189).
  hintStyle: LoopType.bodyLg.copyWith(color: LoopColors.text3),
  border: const OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide.none,
  ),
  enabledBorder: const OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide.none,
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide(color: LoopColors.purple),
  ),
  errorBorder: const OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide(color: LoopColors.danger),
  ),
  focusedErrorBorder: const OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide(color: LoopColors.danger),
  ),
);
