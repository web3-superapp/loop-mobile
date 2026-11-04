import 'package:flutter/material.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The first-level tab strip of the requester's Figma (decision 0277,
/// docs/58 §5.2): equal cells on a full-bleed 1 px white 10 % rule; the
/// chosen cell's word is white 16 / 600 over a 2 px Yellow line the width of
/// the cell, the others textSecondary 16 / 500. A cell may carry a count
/// chip — 11 / 500 on white 5 % at a 2 corner, Purple when chosen and white
/// 60 % otherwise.
///
/// Used by a person's page (持仓 / 交易 / 社区) and any page-level tab row
/// (MEME's 内盘 / 预告 / 已毕业, 聊天's 全部 / 社区 / 好友, 算力榜's boards);
/// a second-level filter is `LoopFilterChips`.
class LoopTabStrip extends StatelessWidget {
  const LoopTabStrip({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.counts,
    this.keys,
    this.padding = const EdgeInsets.symmetric(
      horizontal: LoopSpacing.page,
      vertical: 2,
    ),
    this.scaleDownLabels = false,
  }) : assert(counts == null || counts.length == labels.length),
       assert(keys == null || keys.length == labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// One count per cell, or null for a cell without one.
  final List<int?>? counts;

  /// The widget key of each cell.
  final List<Key>? keys;
  final EdgeInsets padding;

  /// S353b · optional: a word and its count wider than the cell are set a
  /// little smaller instead of being cut with an ellipsis (MEME's English
  /// 「Bonding pool」 at 360). Off by default.
  final bool scaleDownLabels;

  /// The 2 px Yellow line under the chosen cell.
  static const double underline = 2;

  /// A cell's height: the Figma's 38 plus the strip's 2 + 2, which is the
  /// finger's 44 floor less the rule.
  static const double cellHeight = 42;

  /// Between two cells.
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('loop-tab-strip'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.tabRule)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          0,
        ),
        child: Row(
          children: <Widget>[
            for (var index = 0; index < labels.length; index += 1) ...<Widget>[
              if (index > 0) const SizedBox(width: gap),
              Expanded(
                child: _Cell(
                  key: keys?[index],
                  label: labels[index],
                  count: counts?[index],
                  selected: index == selectedIndex,
                  scaleDown: scaleDownLabels,
                  onTap: () {
                    if (index != selectedIndex) LoopHaptics.selection();
                    onSelected(index);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
    this.scaleDown = false,
  });

  final bool scaleDown;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  Widget _fit(Widget row) => scaleDown
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(fit: BoxFit.scaleDown, child: row),
        )
      : row;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = this.count;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null
          ? label
          : '$label${LoopL10n.current.common_listSeparator}$count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: LoopTabStrip.cellHeight,
          child: Stack(
            children: <Widget>[
              Center(
                child: _fit(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (scaleDown)
                        Text(
                          label,
                          maxLines: 1,
                          style: selected ? LoopType.tab : LoopType.tabIdle,
                        )
                      else
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: selected ? LoopType.tab : LoopType.tabIdle,
                          ),
                        ),
                      if (count != null) ...<Widget>[
                        const SizedBox(width: 4),
                        DecoratedBox(
                          key: const ValueKey<String>('loop-tab-strip-count'),
                          decoration: const BoxDecoration(
                            color: LoopColors.white5,
                            borderRadius: LoopRadius.count,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            child: Text(
                              '$count',
                              style: LoopType.count.copyWith(
                                color: selected
                                    ? LoopColors.purple
                                    : LoopColors.white60,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: LoopTabStrip.underline,
                child: AnimatedOpacity(
                  key: ValueKey<String>('loop-tab-strip-line-$selected'),
                  opacity: selected ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: const ColoredBox(color: LoopColors.yellow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
