import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The three sections a person's page splits into (decision 0218): what they
/// hold, what they traded and the communities they are in.
///
/// Another account's page (`user-profile`) and 我的 (S349 · decision 0271
/// Amendment) draw the same bar, so the two pages read as one structure.
enum LoopProfileSection {
  holdings('持仓'),
  trades('交易'),
  communities('社区');

  const LoopProfileSection(this.label);

  final String label;
}

/// 持仓 / 交易 / 社区 under a person's head.
///
/// S350c · decision 0276: the page's own navigation, so it is drawn one
/// step above the filters inside a section (代币 / NFT, the tape's chips):
/// bold words at [LoopType.headline] — Chalk when chosen, the auxiliary ink
/// otherwise — with the 3px Yellow dash, 24 wide, under the chosen one
/// (docs/42 附C §4 顶部页签). No capsule, no Purple: those stay with the
/// filters. The first word stands on the page line.
class LoopProfileSectionsBar extends StatelessWidget {
  const LoopProfileSectionsBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final LoopProfileSection selected;
  final ValueChanged<LoopProfileSection> onSelected;

  /// Room between two words; each word carries [_inset] of its own on
  /// either side, so the gap the eye reads is this plus twice that.
  static const double _gap = 12;
  static const double _inset = 6;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page - _inset,
      LoopSpacing.group,
      LoopSpacing.page,
      0,
    ),
    child: Row(
      children: <Widget>[
        for (final section in LoopProfileSection.values) ...<Widget>[
          if (section.index > 0) const SizedBox(width: _gap),
          _SectionTab(
            key: ValueKey<String>('loop-profile-section-${section.name}'),
            label: section.label,
            selected: section == selected,
            onTap: () {
              if (section != selected) LoopHaptics.selection();
              onSelected(section);
            },
          ),
        ],
      ],
    ),
  );
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: LoopRadius.control,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopTouch.minimum,
            minWidth: LoopTouch.minimum,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LoopProfileSectionsBar._inset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: LoopType.headline.copyWith(
                    color: selected
                        ? LoopGround.inkOf(context)
                        : LoopGround.auxiliaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  key: ValueKey<String>('loop-profile-section-dash-$selected'),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? LoopColors.yellow : Colors.transparent,
                    borderRadius: LoopRadius.pill,
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
