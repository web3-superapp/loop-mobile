import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

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

/// 持仓 / 交易 / 社区 under a person's head, 18 below it.
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
    padding: const EdgeInsets.only(top: 18),
    child: LoopSegBar(
      labels: <String>[
        for (final section in LoopProfileSection.values) section.label,
      ],
      selectedIndex: selected.index,
      onSelected: (index) => onSelected(LoopProfileSection.values[index]),
    ),
  );
}
