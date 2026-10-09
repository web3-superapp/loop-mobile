import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// One OKX-shaped row about a person or an entry (decision 0127): a face on
/// the left, a 16 name with an optional small tag after it, a 13 grey line
/// under it, and one thing on the right — a figure, a capsule or a chevron.
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
  });

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
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LoopSpacing.page,
          vertical: 8,
        ),
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
                          style: LoopTypography.title(
                            16,
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
                      style: LoopTypography.body(13, color: LoopColors.text2),
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

/// A 40 round glyph tile for an entry row that has no face of its own
/// (资料 / 成员 / 语音房 in the manage center, 社区 AI on the record).
class LoopEntryIcon extends StatelessWidget {
  const LoopEntryIcon(this.icon, {super.key, this.size = 40});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: LoopColors.card2,
      shape: BoxShape.circle,
    ),
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
        borderRadius: BorderRadius.circular(6),
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
            style: LoopTypography.label(
              11,
              weight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small capsule action at the end of a row — 「接受」 on a request
/// (decision 0127). Lime when it is the row's one forward step, outlined
/// otherwise. The visible capsule is 32 tall; the touch target is 44.
class LoopPillAction extends StatelessWidget {
  const LoopPillAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ground = !enabled
        ? LoopColors.card2
        : primary
        ? LoopColors.lime
        : Colors.transparent;
    final ink = !enabled
        ? LoopColors.text3
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
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ground,
                borderRadius: BorderRadius.circular(999),
                border: primary || !enabled
                    ? null
                    : Border.all(color: LoopColors.line2),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: LoopTypography.label(
                  13,
                  weight: FontWeight.w600,
                  color: ink,
                ),
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
                style: LoopType.headingSm,
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
  const LoopSeeAll({required this.onPressed, super.key, this.label = '查看全部'});

  final VoidCallback? onPressed;
  final String label;

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
              Text(
                label,
                style: LoopTypography.body(13, color: LoopColors.text2),
              ),
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
  fillColor: LoopColors.card,
  isDense: true,
  constraints: const BoxConstraints(minHeight: 52),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  hintStyle: LoopTypography.body(15, color: LoopColors.text3),
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide.none,
  ),
  enabledBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide.none,
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: LoopColors.lime),
  ),
  errorBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: LoopColors.danger),
  ),
  focusedErrorBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: LoopColors.danger),
  ),
);

/// The page-wide Lime button at the foot of a form (decision 0127): 52 tall,
/// fully rounded, Ink label.
class LoopWideButton extends StatelessWidget {
  const LoopWideButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final ground = !enabled
        ? LoopColors.card2
        : primary
        ? LoopColors.lime
        : LoopColors.card2;
    final ink = !enabled
        ? LoopColors.text3
        : primary
        ? LoopColors.ink
        : LoopColors.chalk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: ground,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: LoopTypography.title(16, color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
