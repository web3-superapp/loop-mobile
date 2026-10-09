import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The OKX flat list voice for second-level pages (decision 0126).
///
/// A page that wraps itself in [LoopFlat] keeps every row, label and notice it
/// already builds, and those widgets draw themselves in the flat voice:
///
/// - [LoopTopbar] — back control, a 20 bold title on one line;
/// - `LoopLabel` — the 17 section title of `LoopSectionTitle` (decision
///   0127), 24 above it, in the page's own words (never upper-cased);
/// - `LoopRecordRow` — 56 tall, no card ground, no shadow, no separator; the
///   `LoopPersonRow` metrics: a 40 round glyph tile, a 16 title, a 13 grey
///   second line, a 14 grey value and a chevron;
/// - `LoopRowIcon` — decision 0127's `LoopEntryIcon` (40 circle, 20 glyph);
/// - `LoopButton(block: true)` — decision 0127's `LoopWideButton` look;
/// - `LoopTogglePreferenceRow` — a Lime [Switch] instead of a state pill;
/// - an informational `LoopNotice` — one 11px grey line with an ⓘ instead of a
///   card. A warning or danger notice keeps its card: that one asks for an
///   action (S121 §1 提示分级 ③).
///
/// Nothing changes outside the scope, so a first-level page that was already
/// designed (聊天, 广场, 钱包首页 …) keeps exactly the shape it has.
class LoopFlat extends InheritedWidget {
  const LoopFlat({required super.child, super.key, this.step = false});

  /// A step page of the account opening: its title is the step's heading at
  /// 24 bold rather than a 20 page title.
  final bool step;

  /// Whether [context] sits inside a flat page.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LoopFlat>() != null;

  /// Whether [context] sits inside a flat step page.
  static bool stepOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LoopFlat>()?.step ?? false;

  /// Row height of a flat entry row.
  static const double rowHeight = 56;

  /// Glyph size at the head of a flat row.
  static const double glyph = 20;

  @override
  bool updateShouldNotify(LoopFlat oldWidget) => oldWidget.step != step;
}

/// The flat page title style: 20, bold.
TextStyle loopFlatTitleStyle() =>
    LoopTypography.heading(20, weight: FontWeight.w700);

/// The flat section title style: 17 semibold, the step `LoopSectionTitle`
/// (decision 0127) uses, so both second-level passes read alike.
TextStyle loopFlatSectionStyle() => LoopType.headingSm;

/// Five-step account opening progress: one dot per step, the current one a
/// Lime pill, the step's name beside it (decision 0126 replaces `04 / 05`).
class LoopStepDots extends StatelessWidget {
  const LoopStepDots({
    required this.step,
    required this.label,
    super.key,
    this.total = 5,
  }) : assert(step >= 1 && step <= total);

  /// One-based current step.
  final int step;
  final int total;

  /// The current step's name, e.g. 「创建钱包」.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey<String>('loop-step-dots'),
      label: '第 $step 步，共 $total 步，$label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          0,
        ),
        child: Row(
          children: <Widget>[
            for (var index = 1; index <= total; index++) ...<Widget>[
              AnimatedContainer(
                key: ValueKey<String>('loop-step-dot-$index'),
                duration: const Duration(milliseconds: 180),
                width: index == step ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index <= step ? LoopColors.lime : LoopColors.line2,
                  borderRadius: LoopRadius.pill,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                key: const ValueKey<String>('loop-step-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.label(13, color: LoopColors.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The flat page heading block of a step page: title 24 bold, subtitle 14
/// grey.
class LoopFlatHeading extends StatelessWidget {
  const LoopFlatHeading({
    required this.title,
    super.key,
    this.subtitle,
    this.top = 20,
  });

  final String title;
  final String? subtitle;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(LoopSpacing.page, top, LoopSpacing.page, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              key: const ValueKey<String>('loop-flat-heading'),
              style: LoopTypography.display(24),
            ),
          ),
          if (subtitle case final String line) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              line,
              key: const ValueKey<String>('loop-flat-subheading'),
              style: LoopTypography.body(14, color: LoopColors.text2),
            ),
          ],
        ],
      ),
    );
  }
}

/// A Lime switch for the flat toggle row. Read-only when [onChanged] is null.
class LoopFlatSwitch extends StatelessWidget {
  const LoopFlatSwitch({required this.value, super.key, this.onChanged});

  final bool value;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Switch(
        value: value,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        activeThumbColor: LoopColors.ink,
        activeTrackColor: LoopColors.lime,
        inactiveThumbColor: LoopColors.text2,
        inactiveTrackColor: LoopColors.card2,
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

/// A labelled form field on a flat page (decision 0126 on decision 0127's
/// form field): the 13 grey label over the field, the field itself the
/// 52-high `loopFormFieldDecoration` card, an optional control beside it and
/// one 11px line under it.
///
/// [boxed] draws that same card around a [child] that is not a text field —
/// a read-only value such as the LOOP ID.
class LoopFlatField extends StatelessWidget {
  const LoopFlatField({
    required this.label,
    required this.child,
    super.key,
    this.trailing,
    this.footnote,
    this.error = false,
    this.boxed = false,
  });

  final String label;

  /// The input itself — a [TextField] with `loopFormFieldDecoration`.
  final Widget child;
  final Widget? trailing;

  /// One 11px line under the field (a count, a rule).
  final String? footnote;
  final bool error;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final field = boxed
        ? Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: AlignmentDirectional.centerStart,
            decoration: const BoxDecoration(
              color: LoopColors.card,
              borderRadius: LoopRadius.inner,
            ),
            child: child,
          )
        : child;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: LoopTypography.label(13, color: LoopColors.text3),
            ),
          ),
          if (trailing case final Widget control)
            Row(
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: 8),
                control,
              ],
            )
          else
            field,
          if (footnote case final String line)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                line,
                style: LoopTypography.caption(
                  11,
                  color: error ? LoopColors.danger : LoopColors.text3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The last line of a flat page: the client version, 11 grey, centred.
class LoopFlatFootnote extends StatelessWidget {
  const LoopFlatFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: LoopTypography.caption(11, color: LoopColors.text3),
      ),
    );
  }
}
