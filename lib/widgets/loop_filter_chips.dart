import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The second-level filter chip of the requester's Figma (decision 0277,
/// docs/58 §5.3): a 54 × 32 rectangle at an 8 corner — white 10 % with a
/// white 13 / 600 word when chosen, white 4 % with a textSecondary 13 / 500
/// word otherwise. It is drawn inside a [LoopTouch.minimum] target, so a tap
/// in the room above or below the face still chooses it.
///
/// One row of them is [LoopFilterChips]. A page-level tab strip is
/// `LoopTabStrip`, one step above.
class LoopFilterChip extends StatefulWidget {
  const LoopFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;

  /// Null draws the chip disabled.
  final VoidCallback? onSelected;

  @override
  State<LoopFilterChip> createState() => _LoopFilterChipState();
}

class _LoopFilterChipState extends State<LoopFilterChip> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant LoopFilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onSelected == null) _pressed = false;
  }

  void _tap() {
    final onSelected = widget.onSelected;
    if (onSelected == null) return;
    // Decision 0130: choosing a peer is a selection; re-choosing is not.
    if (!widget.selected) LoopHaptics.selection();
    onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final face = selected ? LoopColors.chipActive : LoopColors.chipIdle;
    final ground = _pressed
        ? Color.alphaBlend(LoopColors.pressHighlight, face)
        : face;
    final room = math.max(0.0, (LoopTouch.minimum - LoopTouch.chipHeight) / 2);
    return Semantics(
      button: true,
      selected: selected,
      enabled: widget.onSelected != null,
      label: widget.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onSelected == null ? null : _tap,
          onHighlightChanged: (pressed) {
            if (pressed != _pressed) setState(() => _pressed = pressed);
          },
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: room),
            child: DecoratedBox(
              key: const ValueKey<String>('loop-filter-chip-face'),
              decoration: BoxDecoration(
                color: ground,
                borderRadius: LoopRadius.chip,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: LoopTouch.chipMinWidth,
                  minHeight: LoopTouch.chipHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: selected ? LoopType.chip : LoopType.chipIdle,
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

/// A row of [LoopFilterChip]s 8 apart (docs/58 §5.3), with an optional
/// [trailing] control at the row's end (「成员最多」, 「产生算力 ⓘ」, 「＋ 发帖」).
///
/// [keys] names each chip's widget key (`wallet-asset-tab-tokens`, …) so a
/// page keeps the keys its tests and analytics already read.
class LoopFilterChips extends StatelessWidget {
  const LoopFilterChips({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.keys,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    this.scrollable = false,
  }) : assert(keys == null || keys.length == labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<Key>? keys;
  final Widget? trailing;
  final EdgeInsets padding;

  /// Scroll sideways when the chips may not fit the line.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (var index = 0; index < labels.length; index += 1) ...<Widget>[
        if (index > 0) const SizedBox(width: LoopSpacing.chipSpacing),
        LoopFilterChip(
          key: keys?[index],
          label: labels[index],
          selected: index == selectedIndex,
          onSelected: () => onSelected(index),
        ),
      ],
    ];
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: <Widget>[
            ...chips,
            if (trailing != null) ...<Widget>[
              const SizedBox(width: LoopSpacing.chipSpacing),
              trailing!,
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          // A line too narrow for every chip at its natural width shrinks
          // them (English copy runs longer than Chinese). Each chip's share
          // follows its label's length, so a line that fits keeps them whole.
          Expanded(
            child: Row(
              children: <Widget>[
                for (final chip in chips)
                  if (chip is LoopFilterChip)
                    Flexible(flex: chip.label.length + 3, child: chip)
                  else
                    chip,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
