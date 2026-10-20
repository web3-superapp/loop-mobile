import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_ui.dart' show LoopTone;

/// The one state block of the embedded voice media area (decision 0170,
/// docs/33 M3).
///
/// It is the prototype's `.record-card` ground — Card fill, a Line hairline,
/// the card radius — with a sprite glyph, a Chalk title, a Text2 sentence and
/// at most one next step. The v1 state card it replaces painted the amber
/// conversation accent and the danger pink; the prototype has neither
/// (`--amber` is Lime, `--red` is Chalk), so the tone only picks the glyph's
/// colour from the family: Lime for a state that is moving or live, Chalk for
/// one that stopped, Text2 for a plain reading.
class VoiceMediaStateCard extends StatelessWidget {
  const VoiceMediaStateCard({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
    this.tone = LoopTone.neutral,
    this.action,
  });

  final String title;
  final String message;

  /// A name from the prototype sprite (`LoopIconNames`).
  final String icon;
  final LoopTone tone;
  final Widget? action;

  /// The glyph colour a tone is drawn in.
  static Color glyphColor(LoopTone tone) => switch (tone) {
    LoopTone.positive || LoopTone.warning => LoopColors.lime,
    LoopTone.danger => LoopColors.chalk,
    _ => LoopColors.text2,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: LoopColors.card,
        borderRadius: LoopRadius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: LoopIcon(icon, size: 20, color: glyphColor(tone)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: LoopType.title),
                const SizedBox(height: 4),
                Text(message, style: LoopType.bodySm),
                if (action case final Widget next) ...<Widget>[
                  const SizedBox(height: 14),
                  next,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
