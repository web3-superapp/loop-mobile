import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

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
/// S350c · decision 0276: the page's own navigation, one step above the
/// filters inside a section (代币 / NFT, the tape's chips). Decision 0277:
/// it is the Figma's first-level tab strip ([LoopTabStrip], docs/58 §5.2) —
/// equal cells, a white 16 / 600 word over a full-cell 2 px Yellow line when
/// chosen, textSecondary 16 / 500 otherwise, on a white 10 % rule.
class LoopProfileSectionsBar extends StatelessWidget {
  const LoopProfileSectionsBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final LoopProfileSection selected;
  final ValueChanged<LoopProfileSection> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LoopSpacing.group),
    child: LoopTabStrip(
      labels: <String>[
        for (final section in LoopProfileSection.values) section.label,
      ],
      keys: <Key>[
        for (final section in LoopProfileSection.values)
          ValueKey<String>('loop-profile-section-${section.name}'),
      ],
      selectedIndex: selected.index,
      onSelected: (index) => onSelected(LoopProfileSection.values[index]),
    ),
  );
}
