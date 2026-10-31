import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// A small segmented control (UX-015 / UX-016 / UX-017, decision 0257): a
/// low track with equal cells, the chosen cell a slightly raised plate with
/// a Chalk word, the others Text2 words split by short hairlines.
///
/// It is for a quiet choice inside a card — a chart window, a slippage step —
/// where a solid Purple capsule shouted louder than the figure it serves.
/// The whole control is [LoopTouch.minimum] tall, so every cell keeps the 44
/// finger target.
class WalletSegmentedControl<T> extends StatelessWidget {
  const WalletSegmentedControl({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    super.key,
    this.keyOf,
    this.semanticLabel,
    this.expand = true,
    this.onBlocked,
  });

  final List<T> options;
  final String Function(T option) labelOf;

  /// The chosen option; `null` chooses none (a control with nothing behind
  /// it yet).
  final T? selected;

  /// `null` closes the control: every cell keeps its place, is drawn in the
  /// auxiliary ink and answers a tap with [onBlocked] instead.
  final ValueChanged<T>? onSelected;

  /// What a tap does while [onSelected] is `null` — a closed control still
  /// answers the finger that pressed it.
  final VoidCallback? onBlocked;

  /// The key of each cell, for tests and for the page's own lookups.
  final Key Function(T option)? keyOf;

  /// What the group is, for assistive technology (「图表区间」).
  final String? semanticLabel;

  /// Whether the cells share the whole width the parent offers. Off, each
  /// cell is as wide as its word plus padding.
  final bool expand;

  static const double height = LoopTouch.minimum;
  static const double inset = 3;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var index = 0; index < options.length; index += 1) {
      final option = options[index];
      final chosen = option == selected;
      final previousChosen = index > 0 && options[index - 1] == selected;
      if (index > 0) {
        cells.add(
          SizedBox(
            width: 1,
            child: Center(
              child: Container(
                width: 1,
                height: 14,
                color: chosen || previousChosen
                    ? Colors.transparent
                    : LoopColors.line2,
              ),
            ),
          ),
        );
      }
      final choose = onSelected;
      final cell = _Cell(
        key: keyOf?.call(option),
        label: labelOf(option),
        chosen: chosen,
        enabled: choose != null,
        onTap: choose == null
            ? onBlocked
            : () {
                if (!chosen) {
                  LoopHaptics.selection();
                  choose(option);
                }
              },
      );
      cells.add(expand ? Expanded(child: cell) : cell);
    }
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(inset),
        // The plate-card track and a Line2 edge are both there on the
        // grounds the control lands on: the chrome plate, the Ink page, a card.
        decoration: BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.control,
          border: Border.all(color: LoopColors.line2),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: cells,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.chosen,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool chosen;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: chosen,
    enabled: enabled,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // No cross-fade: a chosen plate fading through half-alpha greys is,
      // for a frame or two, a mark that is not there.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: chosen ? LoopColors.card2 : Colors.transparent,
          borderRadius: LoopRadius.inner,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style:
              LoopTypography.withWeight(
                LoopType.label,
                chosen ? FontWeight.w700 : FontWeight.w500,
              ).copyWith(
                color: chosen
                    ? LoopColors.chalk
                    : enabled
                    ? LoopColors.text2
                    : LoopColors.text3,
              ),
        ),
      ),
    ),
  );
}

/// A quiet row of word tabs (S329, decision 0259): no track, no edge, no
/// filled cell, no capsule. The chosen word is Chalk w700 over a 1.5 px Chalk
/// underline; the others are Text3 w500.
///
/// Only the net-worth chart's windows use it: under a chart a segmented
/// control read louder than the line it serves. Each word is drawn
/// [visualHeight] tall, centred in a transparent [LoopTouch.minimum] cell,
/// so the finger target stays 44 while nothing visible grows.
class WalletQuietTabs<T> extends StatelessWidget {
  const WalletQuietTabs({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    super.key,
    this.keyOf,
    this.semanticLabel,
  });

  final List<T> options;
  final String Function(T option) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  /// The key of each word, for tests and for the page's own lookups.
  final Key Function(T option)? keyOf;

  /// What the group is, for assistive technology.
  final String? semanticLabel;

  /// The height of what is drawn: the word and its underline.
  static const double visualHeight = 28;

  /// The touch cell each word sits in.
  static const double height = LoopTouch.minimum;

  static const double horizontalPadding = 8;
  static const double underline = 1.5;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final option in options)
                _QuietTab(
                  key: keyOf?.call(option),
                  label: labelOf(option),
                  chosen: option == selected,
                  onTap: () {
                    if (option == selected) return;
                    LoopHaptics.selection();
                    onSelected(option);
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuietTab extends StatelessWidget {
  const _QuietTab({
    required this.label,
    required this.chosen,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: chosen,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: WalletQuietTabs.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WalletQuietTabs.horizontalPadding,
          ),
          child: Center(
            child: SizedBox(
              height: WalletQuietTabs.visualHeight,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style:
                              LoopTypography.withWeight(
                                LoopType.caption,
                                chosen ? FontWeight.w700 : FontWeight.w500,
                              ).copyWith(
                                color: chosen
                                    ? LoopColors.chalk
                                    : LoopColors.text3,
                              ),
                        ),
                      ),
                    ),
                    // The chosen word's underline; the others keep the room
                    // so a choice moves nothing.
                    SizedBox(
                      height: WalletQuietTabs.underline,
                      child: ColoredBox(
                        color: chosen ? LoopColors.chalk : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
